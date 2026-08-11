#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="${PROJECT_ROOT}/Ansible-modules-01"
VENV_DIR="${PROJECT_ROOT}/.venv"
DOWNLOAD_DIR="${PROJECT_ROOT}/.tools/downloads"
COLLECTIONS_DIR="${ANSIBLE_DIR}/.ansible/collections"

TERRAFORM_VERSION="1.15.3"
KUBECTL_VERSION="1.36.3"
HELM_VERSION="3.18.4"

if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
  echo "ERROR: setup.sh supports Linux x86_64 only." >&2
  exit 1
fi

for command_name in python3 curl unzip sha256sum tar awk grep; do
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
grep " ${terraform_archive}$" "${DOWNLOAD_DIR}/terraform_SHA256SUMS" \
  | sha256sum --check --status
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

export PATH="${VENV_DIR}/bin:${PATH}"
export ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg"
cd "${ANSIBLE_DIR}"
ansible-playbook playbooks/setup_local_environment.yml

printf '\nSetup complete; activate the project tools with: source "%s/bin/activate"\n' \
  "${VENV_DIR}"