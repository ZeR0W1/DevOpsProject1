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

for release in "$@"; do
  helm uninstall "$release" \
    --namespace "$APPLICATION_NAMESPACE" \
    --ignore-not-found \
    --wait
done

kubectl wait \
  --for=delete \
  service \
  --all \
  --namespace "$APPLICATION_NAMESPACE" \
  --timeout=10m

helm uninstall "$JENKINS_RELEASE" \
  --namespace "$JENKINS_NAMESPACE" \
  --ignore-not-found \
  --wait

kubectl delete pvc \
  --all \
  --namespace "$JENKINS_NAMESPACE" \
  --ignore-not-found=true \
  --wait=true

kubectl delete namespace \
  "$APPLICATION_NAMESPACE" \
  "$JENKINS_NAMESPACE" \
  --ignore-not-found=true \
  --wait=true
