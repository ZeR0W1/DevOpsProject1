#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CLUSTER_NAME="devops-app-eks"
REGION=""
NODES=2
NODE_TYPE="t3.small"
NAMESPACE="devops-app"
AUTO_APPROVE=false
YES=false
SKIP_TERRAFORM=false
SKIP_EKS=false

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Run the non-destroy Kubernetes/EKS deployment sequence:
  1. scripts/apply_terraform.sh
  2. scripts/create_eks.sh
  3. scripts/deploy_k8s.sh

Destroy is intentionally excluded. Use scripts/destroy_eks.sh explicitly when
you want to remove the EKS cluster.

Options:
  --cluster-name NAME   EKS cluster name. Default: devops-app-eks
  --region REGION      AWS region. Default: create_eks.sh default
  --nodes COUNT        EKS managed node count. Default: 2
  --node-type TYPE     EKS managed node type. Default: t3.small
  --namespace NAME     Kubernetes namespace. Default: devops-app
  --auto-approve       Auto-approve Terraform apply
  --yes                Skip EKS interactive confirmation
  --skip-terraform     Do not run scripts/apply_terraform.sh
  --skip-eks           Do not run scripts/create_eks.sh
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
    --nodes)
      NODES="${2:?Missing node count}"
      shift 2
      ;;
    --node-type)
      NODE_TYPE="${2:?Missing node type}"
      shift 2
      ;;
    --namespace)
      NAMESPACE="${2:?Missing namespace}"
      shift 2
      ;;
    --auto-approve)
      AUTO_APPROVE=true
      shift
      ;;
    --yes)
      YES=true
      shift
      ;;
    --skip-terraform)
      SKIP_TERRAFORM=true
      shift
      ;;
    --skip-eks)
      SKIP_EKS=true
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

if [[ "$SKIP_TERRAFORM" != "true" ]]; then
  terraform_args=()
  if [[ "$AUTO_APPROVE" == "true" ]]; then
    terraform_args+=(--auto-approve)
  fi
  bash "$PROJECT_ROOT/scripts/apply_terraform.sh" "${terraform_args[@]}"
else
  echo "==> Skipping Terraform by request"
fi

if [[ "$SKIP_EKS" != "true" ]]; then
  eks_args=(--cluster-name "$CLUSTER_NAME" --nodes "$NODES" --node-type "$NODE_TYPE")
  if [[ -n "$REGION" ]]; then
    eks_args+=(--region "$REGION")
  fi
  if [[ "$YES" == "true" ]]; then
    eks_args+=(--yes)
  fi
  bash "$PROJECT_ROOT/scripts/create_eks.sh" "${eks_args[@]}"
else
  echo "==> Skipping EKS create/reuse by request"
fi

bash "$PROJECT_ROOT/scripts/deploy_k8s.sh" --namespace "$NAMESPACE"

echo "==> Full Kubernetes deployment sequence completed"