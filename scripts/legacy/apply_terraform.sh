#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
AUTO_APPROVE=false
PLAN_ONLY=false

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--plan-only] [--auto-approve]

Initialize, validate, plan, and optionally apply Terraform app infrastructure.

This script owns the Terraform part of the workflow. It creates/updates AWS
resources defined in terraform/, including networking, EC2, RDS, S3, SNS, IAM,
Secrets Manager, and CloudWatch resources.

Options:
  --plan-only      Run init/validate/plan only; do not apply changes.
  --auto-approve   Pass -auto-approve to terraform apply.
  -h, --help       Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan-only)
      PLAN_ONLY=true
      shift
      ;;
    --auto-approve)
      AUTO_APPROVE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! command -v terraform >/dev/null 2>&1; then
  echo "ERROR: terraform is required but was not found in PATH" >&2
  exit 127
fi

echo "==> Terraform init"
terraform -chdir="$TERRAFORM_DIR" init -input=false

echo "==> Terraform fmt and validate"
terraform -chdir="$TERRAFORM_DIR" fmt -recursive
terraform -chdir="$TERRAFORM_DIR" validate

echo "==> Terraform plan"
terraform -chdir="$TERRAFORM_DIR" plan -input=false

if [[ "$PLAN_ONLY" == "true" ]]; then
  echo "==> Plan-only mode complete; no AWS resources were changed"
  exit 0
fi

echo "==> Terraform apply"
if [[ "$AUTO_APPROVE" == "true" ]]; then
  terraform -chdir="$TERRAFORM_DIR" apply -input=false -auto-approve
else
  terraform -chdir="$TERRAFORM_DIR" apply -input=false
fi

echo "==> Terraform outputs"
terraform -chdir="$TERRAFORM_DIR" output