"""Trigger one Jenkins rollback build and require its exact result."""

import json
import time
import urllib.error
import urllib.parse

from jenkins_client import (
    JenkinsClient,
    JenkinsLifecycleError,
    required_environment,
    run_safely,
)


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
    environment = required_environment(
        "JENKINS_JOB",
        "REPO_REF",
        "ROLLBACK_REVISION",
    )
    client = JenkinsClient()
    root = client.root
    job = urllib.parse.quote(environment["JENKINS_JOB"], safe="")
    request = client.request
    parameters = {
        "REPO_REF": environment["REPO_REF"],
        "IMAGE_TAG": "",
        "DEPLOY_MODE": "ROLLBACK",
        "ROLLBACK_REVISION": environment["ROLLBACK_REVISION"],
        "CONFIRM_DEPLOY": "true",
    }
    crumb = json.loads(request("/crumbIssuer/api/json")[1])
    status, _, headers = request(
        f"/job/{job}/buildWithParameters",
        "POST",
        urllib.parse.urlencode(parameters).encode(),
        {
            "Content-Type": "application/x-www-form-urlencoded",
            crumb["crumbRequestField"]: crumb["crumb"],
        },
    )
    if status != 201:
        raise JenkinsLifecycleError(f"Unexpected Jenkins queue status {status}")

    queue_url = headers.get("Location", "").rstrip("/")
    if not queue_url.startswith(root + "/queue/item/"):
        raise JenkinsLifecycleError(
            "Jenkins queue response omitted the expected Location"
        )
    queue_path = queue_url[len(root):] + "/api/json"
    queue_id = int(queue_url.rsplit("/", 1)[1])
    build_number = None
    recent_query = urllib.parse.urlencode(
        {"tree": "builds[number,queueId,url,actions[queueId]]{0,20}"}
    )
    for _ in range(600):
        try:
            queue = json.loads(request(queue_path)[1])
        except urllib.error.HTTPError as error:
            if error.code != 404:
                raise
            recent = json.loads(request(f"/job/{job}/api/json?{recent_query}")[1])
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
            raise JenkinsLifecycleError("Jenkins cancelled the queued rollback build")
        if queue.get("executable", {}).get("number") is not None:
            build_number = queue["executable"]["number"]
            break
        time.sleep(5)

    if build_number is None:
        raise JenkinsLifecycleError("Jenkins did not assign the queued rollback build")
    build_path = f"/job/{job}/{build_number}/api/json"
    for _ in range(360):
        build = json.loads(request(build_path)[1])
        if not build.get("building", False) and build.get("result"):
            if build["result"] != "SUCCESS":
                raise JenkinsLifecycleError(
                    f'Jenkins rollback build {build.get("number")} finished '
                    f'{build["result"]}'
                )
            print(f'Jenkins rollback build {build.get("number")} completed SUCCESS.')
            return
        time.sleep(10)
    raise JenkinsLifecycleError("Timed out waiting for Jenkins rollback completion")


if __name__ == "__main__":
    run_safely(main, "CD rollback job")
