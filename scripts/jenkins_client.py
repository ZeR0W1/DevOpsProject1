"""Shared secret-safe diagnostics for project-owned Jenkins API helpers."""

import base64
import http.cookiejar
import json
import os
import sys
import urllib.error
import urllib.request


class JenkinsConfigurationError(RuntimeError):
    """Required non-secret Jenkins helper configuration is missing."""


class JenkinsLifecycleError(RuntimeError):
    """Project-controlled lifecycle failure safe to display to the operator."""


def required_environment(*names):
    """Return required environment values or name missing keys without values."""
    missing = [name for name in names if not os.environ.get(name)]
    if missing:
        raise JenkinsConfigurationError(
            "Missing required Jenkins helper environment: " + ", ".join(missing)
        )
    return {name: os.environ[name] for name in names}


class JenkinsClient:
    """Minimal authenticated Jenkins client shared by lifecycle helpers."""

    def __init__(self):
        environment = required_environment(
            "JENKINS_URL", "JENKINS_USER", "JENKINS_PASSWORD"
        )
        self.root = environment["JENKINS_URL"].rstrip("/")
        credentials = f'{environment["JENKINS_USER"]}:{environment["JENKINS_PASSWORD"]}'
        self.authorization = base64.b64encode(credentials.encode()).decode()
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar())
        )

    def request(
        self,
        path,
        method="GET",
        body=None,
        headers=None,
        expected=None,
    ):
        """Make one Jenkins request and optionally enforce expected statuses."""
        request_headers = {"Authorization": f"Basic {self.authorization}"}
        request_headers.update(headers or {})
        request = urllib.request.Request(
            self.root + path,
            data=body,
            headers=request_headers,
            method=method,
        )
        try:
            with self.opener.open(request, timeout=30) as response:
                if expected is not None and response.status not in expected:
                    raise JenkinsLifecycleError(
                        f"Unexpected Jenkins status {response.status}"
                    )
                return response.status, response.read(), response.headers
        except urllib.error.HTTPError as error:
            if expected is None or error.code not in expected:
                raise
            return error.code, error.read(), error.headers


def describe_jenkins_failure(error, job_kind="job"):
    """Return actionable Jenkins guidance without response bodies or credentials."""
    if isinstance(error, JenkinsConfigurationError):
        return str(error) + "; verify the short-lived helper Job environment and Secrets."
    if isinstance(error, urllib.error.HTTPError):
        if error.code == 401:
            return "Jenkins authentication failed (HTTP 401); verify the admin Secret values."
        if error.code == 403:
            return (
                "Jenkins denied the request (HTTP 403); verify admin permissions "
                "and CSRF configuration."
            )
        if error.code == 404:
            return (
                f"Jenkins returned HTTP 404; verify the configured {job_kind} "
                "and controller URL."
            )
        return (
            f"Jenkins returned unexpected HTTP {error.code}; inspect the controller "
            f"and {job_kind} logs."
        )
    if isinstance(error, urllib.error.URLError):
        return (
            "Jenkins could not be reached; verify controller readiness, service DNS, "
            "and network policy."
        )
    if isinstance(error, (json.JSONDecodeError, KeyError, TypeError, ValueError)):
        return (
            "Jenkins returned an invalid API response; verify controller health and "
            "plugin compatibility."
        )
    if isinstance(error, JenkinsLifecycleError):
        return str(error)
    return (
        f"Unexpected {job_kind} helper failure ({type(error).__name__}); inspect the "
        "short-lived helper Pod logs."
    )


def run_safely(main, job_kind="job"):
    """Run a helper entry point and emit one classified, secret-safe failure."""
    try:
        main()
    except Exception as error:  # noqa: BLE001 - normalize all helper failures
        print(
            f"ERROR: {describe_jenkins_failure(error, job_kind)}",
            file=sys.stderr,
        )
        raise SystemExit(1) from None