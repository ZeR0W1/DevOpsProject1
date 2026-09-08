"""Focused tests for shared Jenkins helper diagnostics."""

import io
import json
import os
import unittest
import urllib.error
from contextlib import redirect_stderr
from email.message import Message
from unittest import mock

import trigger_jenkins_ci
from jenkins_client import (
    JenkinsClient,
    JenkinsConfigurationError,
    JenkinsLifecycleError,
    describe_jenkins_failure,
    required_environment,
    run_safely,
)


class FakeResponse:
    """Context-managed response used by JenkinsClient request tests."""

    def __init__(self, status, body=b"ok"):
        self.status = status
        self.body = body
        self.headers = {"Content-Type": "application/json"}

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def read(self):
        return self.body


class JenkinsClientDiagnosticsTests(unittest.TestCase):
    def setUp(self):
        self.environment = mock.patch.dict(
            os.environ,
            {
                "JENKINS_URL": "http://jenkins.example",
                "JENKINS_USER": "admin-user",
                "JENKINS_PASSWORD": "secret-password",
            },
            clear=True,
        )
        self.environment.start()

    def tearDown(self):
        self.environment.stop()

    def test_required_environment_names_missing_keys_without_values(self):
        del os.environ["JENKINS_PASSWORD"]

        with self.assertRaises(JenkinsConfigurationError) as raised:
            required_environment("JENKINS_USER", "JENKINS_PASSWORD", "REGISTRY_TOKEN")

        message = str(raised.exception)
        self.assertIn("JENKINS_PASSWORD", message)
        self.assertIn("REGISTRY_TOKEN", message)
        self.assertNotIn("admin-user", message)

    def test_http_and_url_failures_do_not_include_body_or_reason(self):
        headers = Message()
        url_error = urllib.error.URLError("secret-password in resolver detail")

        for status in (401, 403, 404, 500):
            error = urllib.error.HTTPError(
                "http://jenkins.example/job/private",
                status,
                "response contains secret-password",
                headers,
                io.BytesIO(b"token=secret-password"),
            )
            message = describe_jenkins_failure(error, "CI job")
            self.assertNotIn("secret-password", message)
            self.assertNotIn("token=", message)
            self.assertIn(str(status), message)

        self.assertIn("could not be reached", describe_jenkins_failure(url_error))

    def test_invalid_response_and_unknown_exception_are_classified(self):
        malformed = json.JSONDecodeError("secret response", "secret-password", 0)
        unknown = OSError("secret-password")

        self.assertIn("invalid API response", describe_jenkins_failure(malformed))
        unknown_message = describe_jenkins_failure(unknown, "seeder")
        self.assertIn("Unexpected seeder helper failure (OSError)", unknown_message)
        self.assertNotIn("secret-password", unknown_message)

    def test_only_controlled_lifecycle_runtime_text_is_displayed(self):
        controlled = JenkinsLifecycleError("Jenkins cancelled the queued CI build")
        uncontrolled = RuntimeError("secret-password in dependency detail")

        self.assertEqual(
            describe_jenkins_failure(controlled),
            "Jenkins cancelled the queued CI build",
        )
        uncontrolled_message = describe_jenkins_failure(uncontrolled)
        self.assertIn("Unexpected job helper failure (RuntimeError)", uncontrolled_message)
        self.assertNotIn("secret-password", uncontrolled_message)

    def test_request_enforces_expected_status_with_mock_opener(self):
        client = JenkinsClient()
        client.opener = mock.Mock()
        client.opener.open.return_value = FakeResponse(202, b"queued")

        with self.assertRaisesRegex(
            JenkinsLifecycleError, "Unexpected Jenkins status 202"
        ):
            client.request("/job/example/build", expected=(201,))

    def test_run_safely_catches_configuration_error_without_secret_value(self):
        del os.environ["JENKINS_PASSWORD"]
        stderr = io.StringIO()

        with redirect_stderr(stderr), self.assertRaises(SystemExit) as raised:
            run_safely(JenkinsClient, "CI job")

        self.assertEqual(raised.exception.code, 1)
        output = stderr.getvalue()
        self.assertIn("JENKINS_PASSWORD", output)
        self.assertNotIn("secret-password", output)

    def test_ci_trigger_accepts_empty_optional_image_tag(self):
        os.environ.update(
            {
                "JENKINS_JOB": "example-ci",
                "DELIVERY_MODE": "BUILD_AND_DEPLOY",
                "DOCKERHUB_NAMESPACE": "example-owner",
                "DEPLOY_IMAGE_TAG": "",
            }
        )
        client = mock.Mock(root="http://jenkins.example")
        client.request.side_effect = [
            (200, b'{"crumbRequestField":"Jenkins-Crumb","crumb":"safe"}', {}),
            (
                201,
                b"",
                {"Location": "http://jenkins.example/queue/item/7"},
            ),
            (200, b'{"executable":{"number":1}}', {}),
            (200, b'{"number":1,"building":false,"result":"SUCCESS"}', {}),
        ]

        with mock.patch.object(trigger_jenkins_ci, "JenkinsClient", return_value=client):
            trigger_jenkins_ci.main()

        queued_body = client.request.call_args_list[1].args[2]
        self.assertIn(b"IMAGE_TAG=", queued_body)


if __name__ == "__main__":
    unittest.main()
