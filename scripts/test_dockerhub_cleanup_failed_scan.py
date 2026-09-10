"""Tests for fail-closed Docker Hub cleanup after image-scan failure."""

import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from scripts.dockerhub_cleanup_failed_scan import (
    CleanupError,
    DockerHubClient,
    load_targets,
    main,
)


VALID_DIGEST = "sha256:" + "a" * 64
OTHER_DIGEST = "sha256:" + "b" * 64


class DockerHubCleanupTests(unittest.TestCase):
    def write_digests(self, directory: Path):
        for component in ("frontend", "backend", "worker"):
            (directory / f"{component}.txt").write_text(
                VALID_DIGEST + "\n", encoding="utf-8"
            )

    @staticmethod
    def repositories():
        return [
            "frontend=example/devops-project1-frontend",
            "backend=example/devops-project1-backend",
            "worker=example/devops-project1-worker",
        ]

    def test_load_targets_requires_exact_service_set_and_immutable_tag(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            digest_directory = Path(temporary_directory)
            self.write_digests(digest_directory)

            with self.assertRaisesRegex(CleanupError, "not latest"):
                load_targets(self.repositories(), "latest", digest_directory)
            with self.assertRaisesRegex(CleanupError, "exactly frontend"):
                load_targets(self.repositories()[:2], "12-deadbeef", digest_directory)

    def test_load_targets_rejects_invalid_recorded_digest(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            digest_directory = Path(temporary_directory)
            self.write_digests(digest_directory)
            (digest_directory / "worker.txt").write_text("not-a-digest\n", encoding="utf-8")

            with self.assertRaisesRegex(CleanupError, "worker"):
                load_targets(self.repositories(), "12-deadbeef", digest_directory)

    def test_verify_requires_exact_live_digest_without_deleting(self):
        client = DockerHubClient("example", "secret")
        client.request = mock.Mock(return_value=(200, json.dumps({"digest": OTHER_DIGEST}).encode()))

        with self.assertRaisesRegex(CleanupError, "does not match"):
            client.verify_tag(
                "example/devops-project1-frontend", "12-deadbeef", VALID_DIGEST
            )

        client.request.assert_called_once_with(
            "GET", "/repositories/example/devops-project1-frontend/tags/12-deadbeef"
        )

    def test_delete_issues_only_the_exact_tag_request(self):
        client = DockerHubClient("example", "secret")
        client.request = mock.Mock(return_value=(204, b""))

        client.delete_tag("example/devops-project1-frontend", "12-deadbeef")

        client.request.assert_called_once_with(
            "DELETE",
            "/repositories/example/devops-project1-frontend/tags/12-deadbeef",
            expected=(204,),
        )

    def test_main_verifies_every_digest_before_first_delete(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            digest_directory = Path(temporary_directory)
            self.write_digests(digest_directory)
            arguments = [
                "dockerhub_cleanup_failed_scan.py",
                "--tag",
                "12-deadbeef",
                "--digest-directory",
                str(digest_directory),
            ]
            for repository in self.repositories():
                arguments.extend(["--repository", repository])
            calls = []

            def record_verify(_client, repository, tag, digest):
                calls.append(("verify", repository, tag, digest))

            def record_delete(_client, repository, tag):
                calls.append(("delete", repository, tag))

            environment = {
                "DOCKERHUB_USERNAME": "example",
                "DOCKERHUB_TOKEN": "secret",
            }
            with mock.patch.dict(os.environ, environment, clear=True), mock.patch(
                "sys.argv", arguments
            ), mock.patch.object(DockerHubClient, "authenticate"), mock.patch.object(
                DockerHubClient, "verify_tag", record_verify
            ), mock.patch.object(DockerHubClient, "delete_tag", record_delete):
                main()

            self.assertEqual([operation[0] for operation in calls], [
                "verify", "verify", "verify", "delete", "delete", "delete"
            ])


if __name__ == "__main__":
    unittest.main()