#!/usr/bin/env bash
set -euo pipefail

readonly E2E_ROOT="/home/geeta/Project1-e2e-clean"
readonly EXPECTED_ACCOUNT="058264247987"
readonly EXPECTED_REGION="us-east-1"
readonly BUCKET="devops-project1-terraform-state-058264247987-us-east-1"
readonly BOOTSTRAP_DIR="${E2E_ROOT}/terraform/state-bootstrap"
readonly MAIN_DIR="${E2E_ROOT}/terraform"
readonly SOURCE_STATE="${BOOTSTRAP_DIR}/terraform.tfstate"
readonly BACKUP_DIR="${E2E_ROOT}/terraform/state_backups"
readonly CONFIRMATION="DELETE-REMOTE-STATE-FOR-ABSOLUTE-ZERO-E2E"

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

require_preconditions() {
  [[ -d "${E2E_ROOT}/.git" ]] || fail "The dedicated E2E checkout is missing."
  [[ "$(git -C "${E2E_ROOT}" branch --show-current)" == "aws4-jenkins-cicd" ]] ||
    fail "The E2E checkout is not on aws4-jenkins-cicd."
  [[ -z "$(git -C "${E2E_ROOT}" status --porcelain --untracked-files=no)" ]] ||
    fail "The E2E checkout has tracked changes."
  [[ "$(git -C "${E2E_ROOT}" rev-parse HEAD)" == "$(git -C "${E2E_ROOT}" rev-parse origin/aws4-jenkins-cicd)" ]] ||
    fail "The E2E checkout does not match the fetched origin/aws4-jenkins-cicd tip."
  [[ -f "${SOURCE_STATE}" ]] || fail "The current E2E bootstrap state is missing."
  [[ "$(stat -c '%a' "${SOURCE_STATE}")" == "600" ]] ||
    fail "The current E2E bootstrap state must be mode 0600."

  actual_account="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)"
  [[ "${actual_account}" == "${EXPECTED_ACCOUNT}" ]] || fail "Unexpected AWS account."
  actual_region="$(aws configure get region 2>/dev/null)"
  [[ "${actual_region}" == "${EXPECTED_REGION}" ]] || fail "Unexpected AWS region."

  main_count="$(terraform -chdir="${MAIN_DIR}" state list 2>/dev/null | wc -l)"
  [[ "${main_count}" -eq 0 ]] || fail "Main Terraform state is not empty."
  bootstrap_count="$(terraform -chdir="${BOOTSTRAP_DIR}" state list 2>/dev/null | wc -l)"
  [[ "${bootstrap_count}" -eq 7 ]] || fail "Bootstrap state does not own exactly seven addresses."
  [[ "$(terraform -chdir="${BOOTSTRAP_DIR}" output -raw state_bucket_name 2>/dev/null)" == "${BUCKET}" ]] ||
    fail "Bootstrap state names a different bucket."

  aws s3api head-bucket --bucket "${BUCKET}" >/dev/null 2>&1 ||
    fail "Expected state bucket is absent or inaccessible."
  [[ "$(aws s3api get-bucket-versioning --bucket "${BUCKET}" --query Status --output text 2>/dev/null)" == "Enabled" ]] ||
    fail "Expected state bucket is not versioned."
  [[ "$(aws s3api get-bucket-tagging --bucket "${BUCKET}" --query 'TagSet[?Key==`ManagedBy`].Value | [0]' --output text 2>/dev/null)" == "TerraformStateBootstrap" ]] ||
    fail "Expected state bucket ownership tag is missing."
}

require_preconditions

if [[ "${1:-}" != "--execute" ]]; then
  printf '%s\n' \
    "Preflight passed: E2E checkout, empty main state, bootstrap ownership, account, region, and bucket controls match." \
    "No changes were made." \
    "Execution requires: $0 --execute ${CONFIRMATION}"
  exit 0
fi

[[ "${2:-}" == "${CONFIRMATION}" ]] || fail "Exact destructive confirmation was not supplied."
[[ $# -eq 2 ]] || fail "Unexpected arguments."

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_state="${BACKUP_DIR}/bootstrap-before-final-absolute-zero-e2e-${timestamp}.tfstate"
mkdir -p "${BACKUP_DIR}"
chmod 700 "${BACKUP_DIR}"
[[ ! -e "${backup_state}" ]] || fail "Refusing to overwrite a bootstrap-state backup."
cp --preserve=mode "${SOURCE_STATE}" "${backup_state}"
chmod 600 "${backup_state}"

delete_manifest="$(mktemp)"
chmod 600 "${delete_manifest}"
trap 'rm -f "${delete_manifest}"' EXIT

object_count=0
while true; do
  aws s3api list-object-versions --bucket "${BUCKET}" --max-items 1000 --output json |
    jq '{Objects: ((.Versions // []) + (.DeleteMarkers // []) | map({Key, VersionId})), Quiet: true}' \
      >"${delete_manifest}"
  batch_count="$(jq '.Objects | length' "${delete_manifest}")"
  (( batch_count > 0 )) || break
  aws s3api delete-objects --bucket "${BUCKET}" --delete "file://${delete_manifest}" >/dev/null
  object_count=$((object_count + batch_count))
done

remaining_count="$(aws s3api list-object-versions --bucket "${BUCKET}" --output json |
  jq '((.Versions // []) + (.DeleteMarkers // [])) | length')"
[[ "${remaining_count}" -eq 0 ]] || fail "Bucket versions remain; bootstrap state backup is preserved."

aws s3api delete-bucket --bucket "${BUCKET}" --region "${EXPECTED_REGION}"
if aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  fail "State bucket still exists; bootstrap state backup is preserved."
fi
rm "${SOURCE_STATE}"

printf 'Absolute-zero boundary established. Bootstrap backup: %s (mode 0600); deleted version entries: %s.\n' \
  "${backup_state}" "${object_count}"