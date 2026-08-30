#!/usr/bin/env python3
"""Purge user-installed content from a verified, disposable EKS cluster."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from collections.abc import Iterable
from typing import Any


SYSTEM_NAMESPACES = {"kube-system", "kube-public", "kube-node-lease"}
SYSTEM_MANAGED_CUSTOM_RESOURCES = {"cninodes.vpcresources.k8s.aws"}
JsonObject = dict[str, Any]


class PurgeError(RuntimeError):
    """Raised when the cluster is not clean enough for Terraform destroy."""


class ClusterPurger:
    def __init__(self) -> None:
        self.kubectl = os.environ["KUBECTL_BIN"]
        self.helm = os.environ["HELM_BIN"]
        self.kubeconfig = os.environ["KUBECONFIG_PATH"]

    def run(
        self,
        command: list[str],
        *,
        check: bool = True,
        quiet: bool = False,
    ) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            command,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if not quiet and result.stdout.strip():
            print(result.stdout.rstrip())
        if check and result.returncode != 0:
            detail = result.stderr.strip() or result.stdout.strip() or "unknown error"
            raise PurgeError(f"Command failed: {' '.join(command)}\n{detail}")
        return result

    def kubectl_run(
        self,
        *arguments: str,
        check: bool = True,
        quiet: bool = False,
    ) -> subprocess.CompletedProcess[str]:
        return self.run(
            [self.kubectl, "--kubeconfig", self.kubeconfig, *arguments],
            check=check,
            quiet=quiet,
        )

    def helm_run(
        self,
        *arguments: str,
        check: bool = True,
        quiet: bool = False,
    ) -> subprocess.CompletedProcess[str]:
        return self.run(
            [self.helm, "--kubeconfig", self.kubeconfig, *arguments],
            check=check,
            quiet=quiet,
        )

    def kubectl_json(self, *arguments: str) -> JsonObject:
        result = self.kubectl_run(*arguments, "-o", "json", quiet=True)
        return json.loads(result.stdout)

    def helm_json(self, *arguments: str) -> list[JsonObject]:
        result = self.helm_run(*arguments, "--output", "json", quiet=True)
        return json.loads(result.stdout)

    @staticmethod
    def items(document: JsonObject) -> list[JsonObject]:
        return list(document.get("items", []))

    def delete_and_require_absent(
        self,
        resource: str,
        delete_arguments: Iterable[str],
        get_arguments: Iterable[str],
        description: str,
    ) -> None:
        result = self.kubectl_run(
            "delete",
            resource,
            *delete_arguments,
            "--ignore-not-found=true",
            "--wait=true",
            "--timeout=10m",
            check=False,
        )
        remaining = self.kubectl_run(
            "get", resource, *get_arguments, "-o", "name", check=False, quiet=True
        )
        if remaining.returncode == 0 and remaining.stdout.strip():
            raise PurgeError(
                f"{description} remain after bounded deletion:\n"
                f"{remaining.stdout.strip()}\n"
                "Finalizers are not stripped automatically. Keep the responsible "
                "controller active and inspect its external cleanup."
            )
        if result.returncode != 0 and remaining.returncode != 0:
            detail = result.stderr.strip() or result.stdout.strip()
            raise PurgeError(f"Could not verify deletion of {description}: {detail}")

    def purge_cloud_entrypoints(self) -> None:
        print("Purging Ingresses and LoadBalancer Services.")
        self.delete_and_require_absent(
            "ingress", ["--all", "--all-namespaces"], ["--all-namespaces"], "Ingresses"
        )
        services = self.items(self.kubectl_json("get", "service", "--all-namespaces"))
        for service in services:
            if service.get("spec", {}).get("type") != "LoadBalancer":
                continue
            metadata = service["metadata"]
            self.delete_and_require_absent(
                "service",
                [str(metadata["name"]), "--namespace", str(metadata["namespace"])],
                [str(metadata["name"]), "--namespace", str(metadata["namespace"])],
                f"LoadBalancer Service {metadata['namespace']}/{metadata['name']}",
            )

    def protect_ebs_deletion(self) -> list[str]:
        volumes = self.items(self.kubectl_json("get", "persistentvolume"))
        names: list[str] = []
        for volume in volumes:
            spec = volume.get("spec", {})
            csi = spec.get("csi", {}) if isinstance(spec, dict) else {}
            if not (
                isinstance(csi, dict) and csi.get("driver") == "ebs.csi.aws.com"
            ) and not (isinstance(spec, dict) and spec.get("awsElasticBlockStore")):
                continue
            name = str(volume["metadata"]["name"])
            names.append(name)
            self.kubectl_run(
                "patch",
                "persistentvolume",
                name,
                "--type=merge",
                "--patch",
                '{"spec":{"persistentVolumeReclaimPolicy":"Delete"}}',
            )
        return names

    def purge_custom_resources(self) -> None:
        print("Purging custom resources while their controllers remain active.")
        for crd in self.items(self.kubectl_json("get", "customresourcedefinition")):
            spec = crd["spec"]
            resource = f"{spec['names']['plural']}.{spec['group']}"
            if resource in SYSTEM_MANAGED_CUSTOM_RESOURCES:
                print(f"Preserving system-managed custom resources: {resource}")
                continue
            if spec["scope"] == "Namespaced":
                delete_args = ["--all", "--all-namespaces"]
                get_args = ["--all-namespaces"]
            else:
                delete_args = ["--all"]
                get_args = []
            self.delete_and_require_absent(
                resource, delete_args, get_args, f"custom resources of type {resource}"
            )

    def purge_helm_releases(self, *, system_releases: bool) -> None:
        category = "system-namespace" if system_releases else "user"
        print(f"Purging {category} Helm releases in the dedicated cluster.")
        releases = [
            release
            for release in self.helm_json("list", "--all", "--all-namespaces")
            if (str(release["namespace"]) in SYSTEM_NAMESPACES) == system_releases
        ]
        for release in releases:
            name = str(release["name"])
            namespace = str(release["namespace"])
            result = self.helm_run(
                "uninstall",
                name,
                "--namespace",
                namespace,
                "--ignore-not-found",
                "--wait",
                "--timeout",
                "10m",
                check=False,
            )
            status = self.helm_run(
                "status", name, "--namespace", namespace, check=False, quiet=True
            )
            if status.returncode == 0:
                detail = result.stderr.strip() or result.stdout.strip()
                raise PurgeError(f"Helm release {namespace}/{name} remains: {detail}")
        remaining = [
            release
            for release in self.helm_json("list", "--all", "--all-namespaces")
            if (str(release["namespace"]) in SYSTEM_NAMESPACES) == system_releases
        ]
        if remaining:
            names = "\n".join(f"{item['namespace']}/{item['name']}" for item in remaining)
            raise PurgeError(f"Helm releases remain after bounded uninstall:\n{names}")

    def purge_user_workloads(self) -> list[str]:
        namespaces = {
            str(item["metadata"]["name"])
            for item in self.items(self.kubectl_json("get", "namespace"))
        }
        user_namespaces = sorted(namespaces - SYSTEM_NAMESPACES - {"default"})
        for namespace in ["default", *user_namespaces]:
            self.kubectl_run(
                "delete",
                "deployment,statefulset,daemonset,replicaset,job,cronjob",
                "--all",
                "--namespace",
                namespace,
                "--ignore-not-found=true",
                "--wait=true",
                "--timeout=10m",
            )
            self.kubectl_run(
                "delete",
                "pod",
                "--all",
                "--namespace",
                namespace,
                "--ignore-not-found=true",
                "--wait=true",
                "--timeout=10m",
            )
        return user_namespaces

    def purge_storage_and_namespaces(
        self, ebs_volume_names: list[str], user_namespaces: list[str]
    ) -> None:
        self.delete_and_require_absent(
            "persistentvolumeclaim",
            ["--all", "--all-namespaces"],
            ["--all-namespaces"],
            "PersistentVolumeClaims",
        )
        for name in ebs_volume_names:
            self.delete_and_require_absent(
                "persistentvolume", [name], [name], f"EBS-backed PV {name}"
            )
        for namespace in user_namespaces:
            self.delete_and_require_absent(
                "namespace", [namespace], [namespace], f"namespace {namespace}"
            )

    def verify(self) -> None:
        ingress = self.kubectl_run(
            "get", "ingress", "--all-namespaces", "-o", "name", quiet=True
        ).stdout.strip()
        services = self.items(self.kubectl_json("get", "service", "--all-namespaces"))
        load_balancers = [
            item for item in services if item.get("spec", {}).get("type") == "LoadBalancer"
        ]
        ebs_volumes = []
        for volume in self.items(self.kubectl_json("get", "persistentvolume")):
            spec = volume.get("spec", {})
            csi = spec.get("csi", {}) if isinstance(spec, dict) else {}
            if (isinstance(csi, dict) and csi.get("driver") == "ebs.csi.aws.com") or (
                isinstance(spec, dict) and spec.get("awsElasticBlockStore")
            ):
                ebs_volumes.append(volume)
        namespaces = {
            str(item["metadata"]["name"])
            for item in self.items(self.kubectl_json("get", "namespace"))
        }
        user_namespaces = namespaces - SYSTEM_NAMESPACES - {"default"}
        releases = self.helm_json("list", "--all", "--all-namespaces")
        if ingress or load_balancers or ebs_volumes or user_namespaces or releases:
            residuals: list[str] = []
            if ingress:
                residuals.append(f"Ingresses:\n{ingress}")
            if load_balancers:
                residuals.append(
                    "LoadBalancer Services:\n"
                    + "\n".join(
                        f"{item['metadata']['namespace']}/{item['metadata']['name']}"
                        for item in load_balancers
                    )
                )
            if ebs_volumes:
                residuals.append(
                    "EBS-backed PVs:\n"
                    + "\n".join(str(item["metadata"]["name"]) for item in ebs_volumes)
                )
            if user_namespaces:
                residuals.append("User namespaces:\n" + "\n".join(sorted(user_namespaces)))
            if releases:
                residuals.append(
                    "Helm releases:\n"
                    + "\n".join(
                        f"{item['namespace']}/{item['name']}" for item in releases
                    )
                )
            raise PurgeError(
                "Dedicated-cluster purge verification found residual resources:\n"
                + "\n\n".join(residuals)
            )
        print("Dedicated-cluster purge boundary verified.")

    def purge(self) -> None:
        self.purge_cloud_entrypoints()
        ebs_volume_names = self.protect_ebs_deletion()
        self.purge_custom_resources()
        self.purge_helm_releases(system_releases=False)
        user_namespaces = self.purge_user_workloads()
        self.purge_helm_releases(system_releases=True)
        self.purge_storage_and_namespaces(ebs_volume_names, user_namespaces)
        self.verify()


def main() -> int:
    try:
        ClusterPurger().purge()
    except (KeyError, json.JSONDecodeError, PurgeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())