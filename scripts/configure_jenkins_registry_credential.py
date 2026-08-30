"""Create or update the lifecycle-managed Docker Hub credential in Jenkins."""

import base64
import http.cookiejar
import json
import os
import urllib.error
import urllib.parse
import urllib.request
from xml.sax.saxutils import escape


ROOT = os.environ["JENKINS_URL"].rstrip("/")
CREDENTIAL_ID = urllib.parse.quote(os.environ["CREDENTIAL_ID"], safe="")
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
    xml = (
        "<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>"
        "<scope>GLOBAL</scope>"
        f"<id>{escape(os.environ['CREDENTIAL_ID'])}</id>"
        "<description>Docker Hub credential managed by guarded Ansible lifecycle</description>"
        f"<username>{escape(os.environ['REGISTRY_USERNAME'])}</username>"
        f"<password>{escape(os.environ['REGISTRY_TOKEN'])}</password>"
        "</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>"
    ).encode()
    headers = {
        "Content-Type": "application/xml",
        crumb["crumbRequestField"]: crumb["crumb"],
    }
    try:
        request(f"/credentials/store/system/domain/_/credential/{CREDENTIAL_ID}/config.xml")
        path = f"/credentials/store/system/domain/_/credential/{CREDENTIAL_ID}/config.xml"
        expected = (200,)
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
        path = "/credentials/store/system/domain/_/createCredentials"
        expected = (200, 201, 302)
    request(path, "POST", xml, headers, expected)
    print("Configured Jenkins Docker Hub credential without exposing its value.")


if __name__ == "__main__":
    main()