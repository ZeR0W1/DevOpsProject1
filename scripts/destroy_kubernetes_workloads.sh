#!/usr/bin/env bash
set -euo pipefail

APPLICATION_NAMESPACE="${1:?Application namespace is required}"
JENKINS_NAMESPACE="${2:?Jenkins namespace is required}"
JENKINS_RELEASE="${3:?Jenkins release is required}"
shift 3

if [[ $# -eq 0 ]]; then
  echo "ERROR: At least one application Helm release is required." >&2
  exit 2
fi

HELM_BIN="${HELM_BIN:?HELM_BIN is required}"
KUBECTL_BIN="${KUBECTL_BIN:?KUBECTL_BIN is required}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:?KUBECONFIG_PATH is required}"

uninstall_release() {
  local release="$1"
  local namespace="$2"

  "$HELM_BIN" --kubeconfig "$KUBECONFIG_PATH" uninstall "$release" \
    --namespace "$namespace" \
    --ignore-not-found \
    --wait \
    --timeout 10m
}

echo "Deleting all Ingress resources before their cloud controllers are removed."
"$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" delete ingress \
  --all \
  --all-namespaces \
  --ignore-not-found=true \
  --wait=true \
  --timeout=10m

load_balancer_services="$(
  "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" get service \
    --all-namespaces \
    -o 'jsonpath={range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}'
)"

while IFS=$'\t' read -r namespace service; do
  [[ -n "$namespace" && -n "$service" ]] || continue
  echo "Deleting cloud-facing Service ${namespace}/${service}."
  "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" delete service "$service" \
    --namespace "$namespace" \
    --ignore-not-found=true \
    --wait=true \
    --timeout=10m
done <<<"$load_balancer_services"

ebs_persistent_volumes="$(
  "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" get persistentvolume \
    -o 'jsonpath={range .items[?(@.spec.csi.driver=="ebs.csi.aws.com")]}{.metadata.name}{"\n"}{end}{range .items[?(@.spec.awsElasticBlockStore.volumeID)]}{.metadata.name}{"\n"}{end}' \
    | sort -u
)"

while IFS= read -r persistent_volume; do
  [[ -n "$persistent_volume" ]] || continue
  echo "Setting EBS-backed PersistentVolume ${persistent_volume} to Delete reclaim policy."
  "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" patch persistentvolume \
    "$persistent_volume" \
    --type=merge \
    --patch '{"spec":{"persistentVolumeReclaimPolicy":"Delete"}}'
done <<<"$ebs_persistent_volumes"

for release in "$@"; do
  uninstall_release "$release" "$APPLICATION_NAMESPACE"
done

uninstall_release "$JENKINS_RELEASE" "$JENKINS_NAMESPACE"

remaining_releases="$(
  "$HELM_BIN" --kubeconfig "$KUBECONFIG_PATH" list \
    --all \
    --all-namespaces \
    --no-headers
)"

while IFS=$'\t' read -r release namespace _; do
  [[ -n "$release" && -n "$namespace" ]] || continue
  echo "Uninstalling discovered Helm release ${namespace}/${release}."
  uninstall_release "$release" "$namespace"
done <<<"$remaining_releases"

"$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" delete pvc \
  --all \
  --all-namespaces \
  --ignore-not-found=true \
  --wait=true \
  --timeout=10m

while IFS= read -r persistent_volume; do
  [[ -n "$persistent_volume" ]] || continue
  echo "Deleting EBS-backed PersistentVolume ${persistent_volume}."
  "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" delete persistentvolume \
    "$persistent_volume" \
    --ignore-not-found=true \
    --wait=true \
    --timeout=10m
done <<<"$ebs_persistent_volumes"

remaining_ebs_pvs="$(
  "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" get persistentvolume \
    -o 'jsonpath={range .items[?(@.spec.csi.driver=="ebs.csi.aws.com")]}{.metadata.name}{"\n"}{end}{range .items[?(@.spec.awsElasticBlockStore.volumeID)]}{.metadata.name}{"\n"}{end}'
)"

if [[ -n "$remaining_ebs_pvs" ]]; then
  echo "ERROR: EBS-backed PersistentVolumes remain after PVC cleanup:" >&2
  printf '%s\n' "$remaining_ebs_pvs" >&2
  echo "Refusing to destroy EKS until cloud-backed storage is released." >&2
  exit 1
fi

"$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" delete namespace \
  "$APPLICATION_NAMESPACE" \
  "$JENKINS_NAMESPACE" \
  --ignore-not-found=true \
  --wait=true
