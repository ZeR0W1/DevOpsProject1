"""Trigger one parameterized Jenkins CI build and require its exact result."""

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
    """Return the queue ID exposed by either supported Jenkins API shape."""
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
    crumb = json.loads(request("/crumbIssuer/api/json")[1])
    parameters = {
        "DELIVERY_MODE": os.environ["DELIVERY_MODE"],
        "IMAGE_TAG": os.environ["DEPLOY_IMAGE_TAG"],
        "DEPLOY_TO_EKS": "true",
    }
    if os.environ["DELIVERY_MODE"] == "BUILD_AND_DEPLOY":
        parameters["DOCKERHUB_NAMESPACE"] = os.environ["DOCKERHUB_NAMESPACE"]

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
    queue_path = queue_url[len(ROOT):] + "/api/json"
    queue_id = int(queue_url.rsplit("/", 1)[1])
    build_number = None
    recent_builds_query = urllib.parse.urlencode(
        {"tree": "builds[number,queueId,url,actions[queueId]]{0,20}"}
    )
    for _ in range(600):
        try:
            queue = json.loads(request(queue_path)[1])
        except urllib.error.HTTPError as error:
            if error.code != 404:
                raise
            recent = json.loads(
                request(f"/job/{JOB}/api/json?{recent_builds_query}")[1]
            )
            assigned = next(
                (
                    build
                    for build in recent.get("builds", [])
                    if build_queue_id(build) == queue_id
                ),
                None,
            )
            if assigned:
                build_number = assigned["number"]
                break
            time.sleep(1)
            continue
        if queue.get("cancelled"):
            raise RuntimeError("Jenkins cancelled the queued CI build")
        if queue.get("executable", {}).get("number") is not None:
            build_number = queue["executable"]["number"]
            break
        time.sleep(5)

    if build_number is None:
        raise RuntimeError("Jenkins did not assign the queued CI build")
    build_path = f"/job/{JOB}/{build_number}/api/json"
    for _ in range(360):
        build = json.loads(request(build_path)[1])
        if not build.get("building", False) and build.get("result"):
            if build["result"] != "SUCCESS":
                raise RuntimeError(
                    f'Jenkins CI build {build.get("number")} finished {build["result"]}'
                )
            print(
                f'Jenkins CI build {build.get("number")} completed SUCCESS '
                f'in {os.environ["DELIVERY_MODE"]} mode.'
            )
            return
        time.sleep(10)
    raise RuntimeError("Timed out waiting for Jenkins CI completion")


if __name__ == "__main__":
    main()
