#!/usr/bin/env python3
"""Delete only Docker Hub tags created by a failed image-scan stage."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


HUB_API = "https://hub.docker.com/v2"
REPOSITORY_PATTERN = re.compile(
    r"^[a-z0-9]+(?:[._-][a-z0-9]+)*/[a-z0-9]+(?:[._-][a-z0-9]+)*$"
)
TAG_PATTERN = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$")
DIGEST_PATTERN = re.compile(r"^sha256:[0-9a-f]{64}$")


class CleanupError(RuntimeError):
    """Raised when cleanup cannot safely verify or delete an exact tag."""


class DockerHubClient:
    """Minimal secret-safe client for Docker Hub tag verification and deletion."""

    def __init__(self, username: str, token: str, opener=None):
        self.username = username
        self.token = token
        self.opener = opener or urllib.request.build_opener()
        self.bearer_token = ""

    def request(self, method: str, path: str, payload=None, expected=(200,)):
        body = None
        headers = {"Accept": "application/json"}
        if payload is not None:
            body = json.dumps(payload).encode("utf-8")
            headers["Content-Type"] = "application/json"
        if self.bearer_token:
            headers["Authorization"] = f"JWT {self.bearer_token}"
        request = urllib.request.Request(
            f"{HUB_API}{path}", data=body, headers=headers, method=method
        )
        try:
            with self.opener.open(request, timeout=20) as response:
                response_body = response.read()
                if response.status not in expected:
                    raise CleanupError(
                        f"Docker Hub returned unexpected HTTP {response.status}."
                    )
                return response.status, response_body
        except urllib.error.HTTPError as error:
            raise CleanupError(f"Docker Hub returned HTTP {error.code}.") from error
        except urllib.error.URLError as error:
            raise CleanupError("Docker Hub could not be reached.") from error

    def authenticate(self):
        _, body = self.request(
            "POST",
            "/users/login",
            {"username": self.username, "password": self.token},
        )
        try:
            bearer_token = json.loads(body)["token"]
        except (KeyError, TypeError, json.JSONDecodeError) as error:
            raise CleanupError("Docker Hub returned an invalid login response.") from error
        if not isinstance(bearer_token, str) or not bearer_token:
            raise CleanupError("Docker Hub returned an empty login token.")
        self.bearer_token = bearer_token

    @staticmethod
    def tag_path(repository: str, tag: str) -> str:
        namespace, name = repository.split("/", 1)
        return "/repositories/{}/{}/tags/{}".format(
            urllib.parse.quote(namespace, safe=""),
            urllib.parse.quote(name, safe=""),
            urllib.parse.quote(tag, safe=""),
        )

    def verify_tag(self, repository: str, tag: str, expected_digest: str):
        path = self.tag_path(repository, tag)
        _, body = self.request("GET", path)
        try:
            actual_digest = json.loads(body)["digest"]
        except (KeyError, TypeError, json.JSONDecodeError) as error:
            raise CleanupError(
                f"Docker Hub returned invalid tag metadata for {repository}:{tag}."
            ) from error
        if actual_digest != expected_digest:
            raise CleanupError(
                f"Refusing to delete {repository}:{tag}: its live digest does not "
                "match this CI build."
            )

    def delete_tag(self, repository: str, tag: str):
        path = self.tag_path(repository, tag)
        self.request("DELETE", path, expected=(204,))
        print(f"Deleted failed-scan Docker Hub tag {repository}:{tag}.")


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", required=True)
    parser.add_argument("--digest-directory", required=True)
    parser.add_argument("--repository", action="append", required=True)
    return parser.parse_args()


def required_environment(name: str) -> str:
    value = os.environ.get(name, "")
    if not value:
        raise CleanupError(f"Required environment variable {name} is missing.")
    return value


def load_targets(repositories: list[str], tag: str, digest_directory: Path):
    if not TAG_PATTERN.fullmatch(tag) or tag == "latest":
        raise CleanupError("Cleanup tag must be immutable, valid, and not latest.")
    targets = []
    seen_components = set()
    for item in repositories:
        try:
            component, repository = item.split("=", 1)
        except ValueError as error:
            raise CleanupError("Repository arguments must use component=namespace/name.") from error
        if component not in {"frontend", "backend", "worker"}:
            raise CleanupError(f"Unsupported cleanup component {component!r}.")
        if component in seen_components:
            raise CleanupError(f"Duplicate cleanup component {component!r}.")
        if not REPOSITORY_PATTERN.fullmatch(repository):
            raise CleanupError(f"Invalid Docker Hub repository for {component}.")
        digest_path = digest_directory / f"{component}.txt"
        try:
            digest = digest_path.read_text(encoding="utf-8").strip()
        except OSError as error:
            raise CleanupError(f"Cannot read the {component} digest file.") from error
        if not DIGEST_PATTERN.fullmatch(digest):
            raise CleanupError(f"Invalid recorded digest for {component}.")
        targets.append((repository, tag, digest))
        seen_components.add(component)
    if seen_components != {"frontend", "backend", "worker"}:
        raise CleanupError("Cleanup requires exactly frontend, backend, and worker.")
    return targets


def main():
    args = parse_args()
    targets = load_targets(
        args.repository, args.tag, Path(args.digest_directory).resolve()
    )
    client = DockerHubClient(
        required_environment("DOCKERHUB_USERNAME"),
        required_environment("DOCKERHUB_TOKEN"),
    )
    client.authenticate()
    for repository, tag, digest in targets:
        client.verify_tag(repository, tag, digest)
    errors = []
    for repository, tag, _digest in targets:
        try:
            client.delete_tag(repository, tag)
        except CleanupError as error:
            errors.append(str(error))
    if errors:
        raise CleanupError(" ".join(errors))


if __name__ == "__main__":
    try:
        main()
    except CleanupError as error:
        print(f"Docker Hub failed-scan cleanup error: {error}", file=sys.stderr)
        raise SystemExit(1)