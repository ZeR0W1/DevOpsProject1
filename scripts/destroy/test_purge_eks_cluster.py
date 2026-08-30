from __future__ import annotations

import importlib.util
import subprocess
import unittest
from pathlib import Path
from unittest.mock import Mock


MODULE_PATH = Path(__file__).with_name("purge_eks_cluster.py")
MODULE_SPEC = importlib.util.spec_from_file_location("purge_eks_cluster", MODULE_PATH)
assert MODULE_SPEC and MODULE_SPEC.loader
MODULE = importlib.util.module_from_spec(MODULE_SPEC)
MODULE_SPEC.loader.exec_module(MODULE)

ClusterPurger = MODULE.ClusterPurger
PurgeError = MODULE.PurgeError


class ClusterPurgerTests(unittest.TestCase):
    def purger(self):
        return ClusterPurger.__new__(ClusterPurger)

    def test_delete_refuses_to_strip_remaining_finalizer(self) -> None:
        purger = self.purger()
        purger.kubectl_run = Mock(
            side_effect=[
                subprocess.CompletedProcess([], 1, "", "timed out"),
                subprocess.CompletedProcess([], 0, "widget.example.io/stuck\n", ""),
            ]
        )

        with self.assertRaisesRegex(PurgeError, "Finalizers are not stripped"):
            purger.delete_and_require_absent(
                "widgets.example.io", ["--all"], [], "test widgets"
            )

    def test_ebs_pvs_are_selected_and_patched_for_deletion(self) -> None:
        purger = self.purger()
        purger.kubectl_json = Mock(
            return_value={
                "items": [
                    {
                        "metadata": {"name": "csi-ebs"},
                        "spec": {"csi": {"driver": "ebs.csi.aws.com"}},
                    },
                    {
                        "metadata": {"name": "legacy-ebs"},
                        "spec": {"awsElasticBlockStore": {"volumeID": "vol-1"}},
                    },
                    {
                        "metadata": {"name": "other"},
                        "spec": {"csi": {"driver": "efs.csi.aws.com"}},
                    },
                ]
            }
        )
        purger.kubectl_run = Mock()

        self.assertEqual(purger.protect_ebs_deletion(), ["csi-ebs", "legacy-ebs"])
        self.assertEqual(purger.kubectl_run.call_count, 2)

    def test_user_helm_pass_does_not_uninstall_system_release(self) -> None:
        purger = self.purger()
        purger.helm_json = Mock(
            side_effect=[
                [
                    {"name": "application", "namespace": "devops-app"},
                    {"name": "controller", "namespace": "kube-system"},
                ],
                [],
            ]
        )
        purger.helm_run = Mock(
            side_effect=[
                subprocess.CompletedProcess([], 0, "", ""),
                subprocess.CompletedProcess([], 1, "", "not found"),
            ]
        )

        purger.purge_helm_releases(system_releases=False)

        uninstall = purger.helm_run.call_args_list[0].args
        self.assertIn("application", uninstall)
        self.assertNotIn("controller", uninstall)

    def test_custom_resource_purge_preserves_eks_vpc_cni_nodes(self) -> None:
        purger = self.purger()
        purger.kubectl_json = Mock(
            return_value={
                "items": [
                    {
                        "spec": {
                            "group": "vpcresources.k8s.aws",
                            "names": {"plural": "cninodes"},
                            "scope": "Cluster",
                        }
                    },
                    {
                        "spec": {
                            "group": "example.io",
                            "names": {"plural": "widgets"},
                            "scope": "Namespaced",
                        }
                    },
                ]
            }
        )
        purger.delete_and_require_absent = Mock()

        purger.purge_custom_resources()

        purger.delete_and_require_absent.assert_called_once_with(
            "widgets.example.io",
            ["--all", "--all-namespaces"],
            ["--all-namespaces"],
            "custom resources of type widgets.example.io",
        )

    def test_purge_orders_controllers_before_storage(self) -> None:
        purger = self.purger()
        calls: list[str] = []
        purger.purge_cloud_entrypoints = lambda: calls.append("entrypoints")
        purger.protect_ebs_deletion = lambda: calls.append("protect-ebs") or ["pv-1"]
        purger.purge_custom_resources = lambda: calls.append("custom-resources")
        purger.purge_helm_releases = lambda **kwargs: calls.append(
            "system-helm" if kwargs["system_releases"] else "user-helm"
        )
        purger.purge_user_workloads = lambda: calls.append("workloads") or ["app"]
        purger.purge_storage_and_namespaces = (
            lambda volumes, namespaces: calls.append("storage")
        )
        purger.verify = lambda: calls.append("verify")

        purger.purge()

        self.assertEqual(
            calls,
            [
                "entrypoints",
                "protect-ebs",
                "custom-resources",
                "user-helm",
                "workloads",
                "system-helm",
                "storage",
                "verify",
            ],
        )


if __name__ == "__main__":
    unittest.main()