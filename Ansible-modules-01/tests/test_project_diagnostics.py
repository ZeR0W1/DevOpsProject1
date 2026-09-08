"""Focused tests for project Ansible diagnostic filters."""

import importlib.util
import unittest
from pathlib import Path

FILTER_PLUGIN_PATH = (
    Path(__file__).resolve().parents[1] / "filter_plugins" / "project_diagnostics.py"
)
SPEC = importlib.util.spec_from_file_location("project_diagnostics", FILTER_PLUGIN_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Unable to load the project diagnostics filter for testing.")
PROJECT_DIAGNOSTICS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PROJECT_DIAGNOSTICS)

FilterModule = PROJECT_DIAGNOSTICS.FilterModule
github_api_diagnostic = PROJECT_DIAGNOSTICS.github_api_diagnostic


class GitHubApiDiagnosticTests(unittest.TestCase):
    def test_known_statuses_are_actionable(self):
        cases = {
            401: "rerun bash setup.sh",
            403: "fine-grained repository permission",
            404: "verify setup repository selection",
            422: "reviewed request inputs",
        }

        for status, expected in cases.items():
            with self.subTest(status=status):
                self.assertIn(expected, github_api_diagnostic(status, "update hooks"))

    def test_operation_appears_only_in_relevant_classifications(self):
        self.assertIn("update hooks", github_api_diagnostic(403, "update hooks"))
        self.assertIn("update hooks", github_api_diagnostic(422, "update hooks"))

    def test_unknown_or_absent_status_uses_safe_connectivity_guidance(self):
        for status in (None, 0, 500):
            with self.subTest(status=status):
                message = github_api_diagnostic(status)
                self.assertIn("unexpected response", message)
                self.assertNotIn("token=", message)

    def test_filter_module_exports_expected_filter(self):
        filters = FilterModule().filters()

        self.assertEqual(filters, {"github_api_diagnostic": github_api_diagnostic})


if __name__ == "__main__":
    unittest.main()