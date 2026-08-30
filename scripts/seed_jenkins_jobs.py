"""Create or update the two Jenkins pipeline jobs from mounted XML files."""

import base64
import http.cookiejar
import json
import os
import pathlib
import urllib.error
import urllib.parse
import urllib.request


ROOT = os.environ["JENKINS_URL"].rstrip("/")
AUTH = base64.b64encode(
    f'{os.environ["JENKINS_USER"]}:{os.environ["JENKINS_PASSWORD"]}'.encode()
).decode()
OPENER = urllib.request.build_opener(
    urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar())
)


def request(path, method="GET", body=None, headers=None, expected=(200,)):
    request_headers = {"Authorization": f"Basic {AUTH}"}
    request_headers.update(headers or {})
    req = urllib.request.Request(
        ROOT + path, data=body, headers=request_headers, method=method
    )
    try:
        with OPENER.open(req, timeout=30) as response:
            if response.status not in expected:
                raise RuntimeError(f"Unexpected Jenkins status {response.status}")
            return response.read()
    except urllib.error.HTTPError as error:
        if error.code not in expected:
            raise
        return error.read()


def main():
    crumb = json.loads(request("/crumbIssuer/api/json"))
    headers = {
        "Content-Type": "application/xml",
        crumb["crumbRequestField"]: crumb["crumb"],
    }
    jobs = (
        ("devops-project1-eks-deploy", "/jobs/cd/config.xml"),
        ("devops-project1-eks-pipeline", "/jobs/ci/config.xml"),
    )
    for name, filename in jobs:
        config = pathlib.Path(filename).read_bytes()
        encoded_name = urllib.parse.quote(name, safe="")
        try:
            request(f"/job/{encoded_name}/config.xml")
            path = f"/job/{encoded_name}/config.xml"
            expected = (200,)
        except urllib.error.HTTPError as error:
            if error.code != 404:
                raise
            path = f"/createItem?name={encoded_name}"
            expected = (200, 201)
        request(path, "POST", config, headers, expected)
        print(f"Seeded Jenkins job: {name}")


if __name__ == "__main__":
    main()