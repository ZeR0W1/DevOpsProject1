"""Trigger one Jenkins rollback build and require its exact result."""

import base64
import http.cookiejar
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request


ROOT = os.environ["JENKINS_URL"].rstrip("/")
JOB = urllib.parse.quote(os.environ["JENKINS_JOB"], safe="")
AUTH = base64.b64encode(
    f'{os.environ["JENKINS_USER"]}:{os.environ["JENKINS_PASSWORD"]}'.encode()
).decode()
OPENER = urllib.request.build_opener(
    urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar())
)


def request(path, method="GET", body=None, headers=None):
    request_headers = {"Authorization": f"Basic {AUTH}"}
    request_headers.update(headers or {})
    req = urllib.request.Request(
        ROOT + path,
        data=body,
        headers=request_headers,
        method=method,
    )
    with OPENER.open(req, timeout=30) as response:
        return response.status, response.read(), response.headers


def build_queue_id(build):
    if build.get("queueId") is not None:
        return build["queueId"]
    return next(
        (
            action["queueId"]
            for action in build.get("actions", [])
            if action.get("queueId") is not None
        ),
        None,
    )


def main():
    parameters = {
        "REPO_REF": os.environ["REPO_REF"],
        "IMAGE_TAG": "",
        "DEPLOY_MODE": "ROLLBACK",
        "ROLLBACK_REVISION": os.environ["ROLLBACK_REVISION"],
        "CONFIRM_DEPLOY": "true",
    }
    crumb = json.loads(request("/crumbIssuer/api/json")[1])
    status, _, headers = request(
        f"/job/{JOB}/buildWithParameters",
        "POST",
        urllib.parse.urlencode(parameters).encode(),
        {
            "Content-Type": "application/x-www-form-urlencoded",
            crumb["crumbRequestField"]: crumb["crumb"],
        },
    )
    if status != 201:
        raise RuntimeError(f"Unexpected Jenkins queue status {status}")

    queue_url = headers.get("Location", "").rstrip("/")
    if not queue_url.startswith(ROOT + "/queue/item/"):
        raise RuntimeError("Jenkins queue response omitted the expected Location")
    queue_path = queue_url[len(ROOT) :] + "/api/json"
    queue_id = int(queue_url.rsplit("/", 1)[1])
    build_url = ""
    recent_query = urllib.parse.urlencode(
        {"tree": "builds[number,queueId,url,actions[queueId]]{0,20}"}
    )
    for _ in range(600):
        try:
            queue = json.loads(request(queue_path)[1])
        except urllib.error.HTTPError as error:
            if error.code != 404:
                raise
            recent = json.loads(request(f"/job/{JOB}/api/json?{recent_query}")[1])
            assigned = next(
                (
                    build
                    for build in recent.get("builds", [])
                    if build_queue_id(build) == queue_id
                ),
                None,
            )
            if assigned:
                build_url = assigned["url"].rstrip("/")
                break
            time.sleep(1)
            continue
        if queue.get("cancelled"):
            raise RuntimeError("Jenkins cancelled the queued rollback build")
        if queue.get("executable", {}).get("url"):
            build_url = queue["executable"]["url"].rstrip("/")
            break
        time.sleep(5)

    if not build_url.startswith(ROOT + "/job/"):
        raise RuntimeError("Jenkins did not assign the queued rollback build")
    build_path = build_url[len(ROOT) :] + "/api/json"
    for _ in range(360):
        build = json.loads(request(build_path)[1])
        if not build.get("building", False) and build.get("result"):
            if build["result"] != "SUCCESS":
                raise RuntimeError(
                    f'Jenkins rollback build {build.get("number")} finished '
                    f'{build["result"]}'
                )
            print(f'Jenkins rollback build {build.get("number")} completed SUCCESS.')
            return
        time.sleep(10)
    raise RuntimeError("Timed out waiting for Jenkins rollback completion")


if __name__ == "__main__":
    main()