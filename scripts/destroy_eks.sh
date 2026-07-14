#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="devops-app-eks"
REGION="us-east-1"
CONFIRM=false

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Destroy the EKS cluster created by scripts/create_eks.sh.

This intentionally does not destroy Terraform-managed app infrastructure.
Use terraform destroy separately for VPC/EC2/RDS/S3/SNS/IAM resources.

Options:
  --cluster-name NAME   EKS cluster name. Default: devops-app-eks
  --region REGION      AWS region. Default: us-east-1
  --yes                Skip interactive confirmation
  -h, --help           Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster-name)
      CLUSTER_NAME="${2:?Missing cluster name}"
      shift 2
      ;;
    --region)
      REGION="${2:?Missing region}"
      shift 2
      ;;
    --yes)
      CONFIRM=true
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

if ! command -v eksctl >/dev/null 2>&1; then
  echo "ERROR: eksctl is required but was not found in PATH" >&2
  exit 127
fi

echo "About to delete EKS cluster '$CLUSTER_NAME' in region '$REGION'."
if [[ "$CONFIRM" != "true" ]]; then
  read -r -p "Continue? Type 'delete' to proceed: " answer
  if [[ "$answer" != "delete" ]]; then
    echo "Aborted."
    exit 1
  fi
fi

eksctl delete cluster --name "$CLUSTER_NAME" --region "$REGION"