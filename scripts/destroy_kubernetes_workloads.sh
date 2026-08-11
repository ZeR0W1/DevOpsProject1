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

for release in "$@"; do
  "$HELM_BIN" --kubeconfig "$KUBECONFIG_PATH" uninstall "$release" \
    --namespace "$APPLICATION_NAMESPACE" \
    --ignore-not-found \
    --wait
done

"$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" wait \
  --for=delete \
  service \
  --all \
  --namespace "$APPLICATION_NAMESPACE" \
  --timeout=10m

"$HELM_BIN" --kubeconfig "$KUBECONFIG_PATH" uninstall "$JENKINS_RELEASE" \
  --namespace "$JENKINS_NAMESPACE" \
  --ignore-not-found \
  --wait

"$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" delete pvc \
  --all \
  --namespace "$JENKINS_NAMESPACE" \
  --ignore-not-found=true \
  --wait=true

"$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" delete namespace \
  "$APPLICATION_NAMESPACE" \
  "$JENKINS_NAMESPACE" \
  --ignore-not-found=true \
  --wait=true
