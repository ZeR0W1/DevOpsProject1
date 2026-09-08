"""Create or update the two Jenkins pipeline jobs from mounted XML files."""

import json
import pathlib
import urllib.error
import urllib.parse

from jenkins_client import JenkinsClient, run_safely


def main():
    request = JenkinsClient().request
    crumb = json.loads(request("/crumbIssuer/api/json", expected=(200,))[1])
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
            request(f"/job/{encoded_name}/config.xml", expected=(200,))
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
    run_safely(main, "pipeline job")