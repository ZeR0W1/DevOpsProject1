#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kubeconfig="${KUBECONFIG:-${project_root}/Ansible-modules-01/recovery/target-kubeconfig}"

command -v kubectl >/dev/null || {
  printf '%s\n' 'kubectl is required.' >&2
  exit 1
}
command -v jq >/dev/null || {
  printf '%s\n' 'jq is required.' >&2
  exit 1
}
[[ -f "${kubeconfig}" ]] || {
  printf 'Kubeconfig not found: %s\n' "${kubeconfig}" >&2
  exit 1
}

printf '%s\n' 'This prints the current Jenkins administrator password to this terminal only.'
printf '%s\n' 'It does not copy, cache, or write the credentials to a file.'
read -r -p 'Type SHOW to continue: ' confirmation
if [[ "${confirmation}" != "SHOW" ]]; then
  printf '%s\n' 'Cancelled; no credential was read.'
  exit 1
fi

secret_json="$(kubectl --kubeconfig "${kubeconfig}" -n jenkins get secret jenkins -o json)"
username="$(printf '%s' "${secret_json}" | jq -r '.data["jenkins-admin-user"] | @base64d')"
password="$(printf '%s' "${secret_json}" | jq -r '.data["jenkins-admin-password"] | @base64d')"
unset secret_json

printf 'Username: %s\n' "${username}"
printf 'Password: %s\n' "${password}"
unset username password