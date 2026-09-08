"""Create or update the lifecycle-managed Docker Hub credential in Jenkins."""

import json
import urllib.error
import urllib.parse
from xml.sax.saxutils import escape

from jenkins_client import JenkinsClient, required_environment, run_safely


def main():
    environment = required_environment(
        "CREDENTIAL_ID",
        "REGISTRY_USERNAME",
        "REGISTRY_TOKEN",
    )
    credential_id = urllib.parse.quote(environment["CREDENTIAL_ID"], safe="")
    request = JenkinsClient().request
    crumb = json.loads(request("/crumbIssuer/api/json", expected=(200,))[1])
    xml = (
        "<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>"
        "<scope>GLOBAL</scope>"
        f"<id>{escape(environment['CREDENTIAL_ID'])}</id>"
        "<description>Docker Hub credential managed by guarded Ansible lifecycle</description>"
        f"<username>{escape(environment['REGISTRY_USERNAME'])}</username>"
        f"<password>{escape(environment['REGISTRY_TOKEN'])}</password>"
        "</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>"
    ).encode()
    headers = {
        "Content-Type": "application/xml",
        crumb["crumbRequestField"]: crumb["crumb"],
    }
    try:
        request(
            f"/credentials/store/system/domain/_/credential/{credential_id}/config.xml",
            expected=(200,),
        )
        path = f"/credentials/store/system/domain/_/credential/{credential_id}/config.xml"
        expected = (200,)
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
        path = "/credentials/store/system/domain/_/createCredentials"
        expected = (200, 201, 302)
    request(path, "POST", xml, headers, expected)
    print("Configured Jenkins Docker Hub credential without exposing its value.")


if __name__ == "__main__":
    run_safely(main, "registry credential")