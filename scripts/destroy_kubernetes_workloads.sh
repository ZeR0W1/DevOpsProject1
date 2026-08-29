#!/usr/bin/env bash
set -euo pipefail

HELM_BIN="${HELM_BIN:?HELM_BIN is required}"
KUBECTL_BIN="${KUBECTL_BIN:?KUBECTL_BIN is required}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:?KUBECONFIG_PATH is required}"

readonly -a SYSTEM_NAMESPACES=(kube-system kube-public kube-node-lease)

is_system_namespace() {
  local candidate="$1"
  local system_namespace

  for system_namespace in "${SYSTEM_NAMESPACES[@]}"; do
    if [[ "$candidate" == "$system_namespace" ]]; then
      return 0
    fi
  done

  return 1
}

uninstall_release() {
  local release="$1"
  local namespace="$2"

  if ! "$HELM_BIN" --kubeconfig "$KUBECONFIG_PATH" uninstall "$release" \
      --namespace "$namespace" \
      --ignore-not-found \
      --wait \
      --timeout 10m; then
    if ! "$HELM_BIN" --kubeconfig "$KUBECONFIG_PATH" status "$release" \
        --namespace "$namespace" >/dev/null 2>&1; then
      echo "Release ${namespace}/${release} is absent after Helm reported an uninstall error; continuing."
      return 0
    fi

    echo "ERROR: Helm release ${namespace}/${release} still exists after uninstall failed." >&2
    return 1
  fi
}

delete_custom_resources() {
  local resource
  local scope
  local remaining
  local -a delete_arguments
  local -a get_arguments

  while IFS=$'\t' read -r resource scope; do
    [[ -n "$resource" && -n "$scope" ]] || continue
    if [[ "$scope" == "Namespaced" ]]; then
      delete_arguments=(--all --all-namespaces)
      get_arguments=(--all-namespaces)
    else
      delete_arguments=(--all)
      get_arguments=()
    fi

    if ! "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" delete "$resource" \
        "${delete_arguments[@]}" \
        --ignore-not-found=true \
        --wait=true \
        --timeout=5m; then
      remaining="$(
        "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" get "$resource" \
          "${get_arguments[@]}" \
          -o name 2>/dev/null || true
      )"
      if [[ -n "$remaining" ]]; then
        echo "ERROR: ${resource} custom resources remain:" >&2
        printf '%s\n' "$remaining" >&2
        echo "Refusing to strip finalizers automatically; the responsible controller must finish cleanup." >&2
        return 1
      fi
    fi
  done <<<"$custom_resource_types"
}

delete_workload_controllers() {
  local namespace="$1"

  "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" delete \
    deployment,statefulset,daemonset,replicaset,job,cronjob \
    --all \
    --namespace "$namespace" \
    --ignore-not-found=true \
    --wait=true \
    --timeout=10m
  "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" delete pod \
    --all \
    --namespace "$namespace" \
    --ignore-not-found=true \
    --wait=true \
    --timeout=10m
}

user_namespaces="$(
  "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" get namespace \
    -o json \
    | jq -r '.items[].metadata.name' \
    | while IFS= read -r namespace; do
        if [[ "$namespace" != "default" ]] && ! is_system_namespace "$namespace"; then
          printf '%s\n' "$namespace"
        fi
      done
)"

purge_namespaces="$(printf 'default\n%s\n' "$user_namespaces" | awk 'NF' | sort -u)"

custom_resource_types="$(
  "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" get customresourcedefinition \
    -o json \
    | jq -r '.items[] | [.spec.names.plural + "." + .spec.group, .spec.scope] | @tsv' \
    | sort -u
)"

discovered_releases="$(
  "$HELM_BIN" --kubeconfig "$KUBECONFIG_PATH" list \
    --all \
    --all-namespaces \
    --output json \
    | jq -r '.[] | [.name, .namespace] | @tsv'
)"

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

echo "Deleting CRD-backed resources while their controllers can still finalize them."
delete_custom_resources

while IFS=$'\t' read -r release namespace; do
  [[ -n "$release" && -n "$namespace" ]] || continue
  echo "Uninstalling discovered Helm release ${namespace}/${release}."
  uninstall_release "$release" "$namespace"
done <<<"$discovered_releases"

echo "Removing workloads recreated during controller and Helm finalization."
while IFS= read -r namespace; do
  [[ -n "$namespace" ]] || continue
  delete_workload_controllers "$namespace"
done <<<"$purge_namespaces"

"$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" delete pvc \
  --all \
  --all-namespaces \
  --ignore-not-found=true \
  --wait=true \
  --timeout=10m

remaining_ebs_pvs="$(
  "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" get persistentvolume \
    -o 'jsonpath={range .items[?(@.spec.csi.driver=="ebs.csi.aws.com")]}{.metadata.name}{"\n"}{end}{range .items[?(@.spec.awsElasticBlockStore.volumeID)]}{.metadata.name}{"\n"}{end}' \
    | sort -u
)"

while IFS= read -r persistent_volume; do
  [[ -n "$persistent_volume" ]] || continue
  echo "Deleting EBS-backed PersistentVolume ${persistent_volume}."
  "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" delete persistentvolume \
    "$persistent_volume" \
    --ignore-not-found=true \
    --wait=true \
    --timeout=10m
done <<<"$remaining_ebs_pvs"

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

while IFS= read -r namespace; do
  [[ -n "$namespace" ]] || continue
  echo "Deleting user namespace ${namespace}."
  if ! "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" delete namespace "$namespace" \
      --ignore-not-found=true \
      --wait=true \
      --timeout=10m; then
    remaining_namespace="$(
      "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" get namespace "$namespace" \
        -o name 2>/dev/null || true
    )"
    if [[ -n "$remaining_namespace" ]]; then
      echo "ERROR: Namespace ${namespace} remains, usually because a resource finalizer has not completed." >&2
      echo "Refusing to strip finalizers automatically; inspect the responsible controller and external resource." >&2
      exit 1
    fi
  fi
done <<<"$user_namespaces"

remaining_ingresses="$(
  "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" get ingress \
    --all-namespaces \
    -o name 2>/dev/null || true
)"
remaining_load_balancer_services="$(
  "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" get service \
    --all-namespaces \
    -o 'jsonpath={range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.namespace}{"/"}{.metadata.name}{"\n"}{end}'
)"
remaining_releases="$(
  "$HELM_BIN" --kubeconfig "$KUBECONFIG_PATH" list \
    --all \
    --all-namespaces \
    --output json \
    | jq -r '.[] | [.namespace, .name] | join("/")'
)"
remaining_user_namespaces="$(
  "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" get namespace \
    -o json \
    | jq -r '.items[].metadata.name' \
    | while IFS= read -r namespace; do
        if [[ "$namespace" != "default" ]] && ! is_system_namespace "$namespace"; then
          printf '%s\n' "$namespace"
        fi
      done
)"

if [[ -n "$remaining_ingresses" ]]; then
  echo "ERROR: Ingress resources remain after dedicated-cluster purge:" >&2
  printf '%s\n' "$remaining_ingresses" >&2
  exit 1
fi

if [[ -n "$remaining_load_balancer_services" ]]; then
  echo "ERROR: LoadBalancer Services remain after dedicated-cluster purge:" >&2
  printf '%s\n' "$remaining_load_balancer_services" >&2
  exit 1
fi

if [[ -n "$remaining_releases" ]]; then
  echo "ERROR: Helm releases remain after dedicated-cluster purge:" >&2
  printf '%s\n' "$remaining_releases" >&2
  exit 1
fi

if [[ -n "$remaining_user_namespaces" ]]; then
  echo "ERROR: User namespaces remain after dedicated-cluster purge:" >&2
  printf '%s\n' "$remaining_user_namespaces" >&2
  echo "Refusing to strip namespace or resource finalizers automatically." >&2
  exit 1
fi

echo "Dedicated-cluster purge verified: no Ingresses, LoadBalancer Services, Helm releases, EBS-backed PVs, or user namespaces remain."
