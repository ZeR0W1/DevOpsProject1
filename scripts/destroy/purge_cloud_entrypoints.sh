#!/usr/bin/env bash
set -euo pipefail

KUBECTL_BIN="${KUBECTL_BIN:?KUBECTL_BIN is required}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:?KUBECONFIG_PATH is required}"

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
  echo "Deleting LoadBalancer Service ${namespace}/${service}."
  "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" delete service "$service" \
    --namespace "$namespace" \
    --ignore-not-found=true \
    --wait=true \
    --timeout=10m
done <<<"$load_balancer_services"