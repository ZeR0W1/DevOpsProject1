#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="${PROJECT_ROOT}/Ansible-modules-01"
VENV_DIR="${PROJECT_ROOT}/.venv"
TOOLS_DIR="${PROJECT_ROOT}/.tools"
DOWNLOAD_DIR="${TOOLS_DIR}/downloads"
ANSIBLE_RUNTIME_DIR="${ANSIBLE_DIR}/.ansible"
COLLECTIONS_DIR="${ANSIBLE_DIR}/collections"
VAULT_PASSWORD_FILE="${ANSIBLE_DIR}/.vault-password"
LOCAL_ENVIRONMENT_FILE="${ANSIBLE_DIR}/vault/local-environment.yml"

if [[ "${1:-}" == "refresh-github-hooks" ]]; then
  if [[ $# -ne 1 ]]; then
    echo "ERROR: refresh-github-hooks accepts no additional arguments." >&2
    exit 2
  fi
  if [[ ! -x "${VENV_DIR}/bin/ansible-playbook" ]]; then
    echo "ERROR: Run bash setup.sh before refreshing GitHub hook CIDRs." >&2
    exit 1
  fi
  export PATH="${VENV_DIR}/bin:${PATH}"
  export ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg"
  cd "${ANSIBLE_DIR}"
  exec ansible-playbook playbooks/refresh_github_hook_cidrs.yml
fi

if [[ $# -ne 0 ]]; then
  echo "Usage: bash setup.sh [refresh-github-hooks]" >&2
  exit 2
fi

declare -a SETUP_ROLLBACK_PATHS=()

for setup_path in \
  "${VENV_DIR}" \
  "${TOOLS_DIR}" \
  "${ANSIBLE_RUNTIME_DIR}" \
  "${VAULT_PASSWORD_FILE}" \
  "${LOCAL_ENVIRONMENT_FILE}"; do
  if [[ ! -e "${setup_path}" ]]; then
    SETUP_ROLLBACK_PATHS+=("${setup_path}")
  fi
done

rollback_failed_setup() {
  local exit_code=$?
  trap - ERR
  if ((${#SETUP_ROLLBACK_PATHS[@]} > 0)); then
    echo "ERROR: Setup failed; removing only artifacts created by this invocation." >&2
    rm -rf -- "${SETUP_ROLLBACK_PATHS[@]}"
  fi
  exit "${exit_code}"
}

trap rollback_failed_setup ERR

TERRAFORM_VERSION="1.15.3"
KUBECTL_VERSION="1.36.3"
HELM_VERSION="3.18.4"

if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
  echo "ERROR: setup.sh supports Linux x86_64 only." >&2
  exit 1
fi

for command_name in python3 curl unzip sha256sum tar awk grep openssl git jq; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "ERROR: Install ${command_name} and rerun setup.sh; sudo is never used automatically." >&2
    exit 1
  fi
done

mkdir -p "${DOWNLOAD_DIR}" "${COLLECTIONS_DIR}"
python3 -m venv "${VENV_DIR}"
"${VENV_DIR}/bin/python" -m pip install --upgrade pip
"${VENV_DIR}/bin/python" -m pip install -r "${ANSIBLE_DIR}/requirements-controller.txt"

terraform_archive="terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
curl --fail --location --silent --show-error \
  --output "${DOWNLOAD_DIR}/${terraform_archive}" \
  "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${terraform_archive}"
curl --fail --location --silent --show-error \
  --output "${DOWNLOAD_DIR}/terraform_SHA256SUMS" \
  "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS"
(cd "${DOWNLOAD_DIR}" && \
  grep " ${terraform_archive}$" terraform_SHA256SUMS \
    | sha256sum --check --status)
unzip -o -q "${DOWNLOAD_DIR}/${terraform_archive}" -d "${VENV_DIR}/bin"

curl --fail --location --silent --show-error \
  --output "${DOWNLOAD_DIR}/kubectl" \
  "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
curl --fail --location --silent --show-error \
  --output "${DOWNLOAD_DIR}/kubectl.sha256" \
  "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"
printf '%s  %s\n' "$(cat "${DOWNLOAD_DIR}/kubectl.sha256")" "${DOWNLOAD_DIR}/kubectl" \
  | sha256sum --check --status
install -m 0755 "${DOWNLOAD_DIR}/kubectl" "${VENV_DIR}/bin/kubectl"

helm_archive="helm-v${HELM_VERSION}-linux-amd64.tar.gz"
curl --fail --location --silent --show-error \
  --output "${DOWNLOAD_DIR}/${helm_archive}" \
  "https://get.helm.sh/${helm_archive}"
curl --fail --location --silent --show-error \
  --output "${DOWNLOAD_DIR}/${helm_archive}.sha256sum" \
  "https://get.helm.sh/${helm_archive}.sha256sum"
(cd "${DOWNLOAD_DIR}" && sha256sum --check --status "${helm_archive}.sha256sum")
tar -xzf "${DOWNLOAD_DIR}/${helm_archive}" -C "${DOWNLOAD_DIR}"
install -m 0755 "${DOWNLOAD_DIR}/linux-amd64/helm" "${VENV_DIR}/bin/helm"

"${VENV_DIR}/bin/ansible-galaxy" collection install \
  --requirements-file "${ANSIBLE_DIR}/requirements-collections.yml" \
  --collections-path "${COLLECTIONS_DIR}"

if [[ ! -e "${VAULT_PASSWORD_FILE}" ]]; then
  umask 077
  openssl rand -base64 48 >"${VAULT_PASSWORD_FILE}"
fi

export PATH="${VENV_DIR}/bin:${PATH}"
export ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg"
cd "${ANSIBLE_DIR}"
ansible-playbook playbooks/setup_local_environment.yml

chmod 0755 "${PROJECT_ROOT}/.githooks/pre-push"
git -C "${PROJECT_ROOT}" config --local core.hooksPath .githooks

trap - ERR
printf '\nSetup complete; activate the project tools with: source "%s/bin/activate"\n' \
  "${VENV_DIR}"