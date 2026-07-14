#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

CLUSTER_NAME="devops-app-eks"
REGION=""
NODES=2
NODE_TYPE="t3.small"
CONFIRM=false

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Create or reuse an EKS cluster and update kubeconfig for kubectl/helm.

Options:
  --cluster-name NAME   EKS cluster name. Default: devops-app-eks
  --region REGION      AWS region. Default: Terraform aws_region output, then us-east-1
  --nodes COUNT        Managed node count. Default: 2
  --node-type TYPE     Managed node EC2 type. Default: t3.small
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
    --nodes)
      NODES="${2:?Missing node count}"
      shift 2
      ;;
    --node-type)
      NODE_TYPE="${2:?Missing node type}"
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

for command_name in eksctl aws kubectl; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $command_name" >&2
    exit 127
  fi
done

if [[ -z "$REGION" ]]; then
  if command -v terraform >/dev/null 2>&1 && terraform -chdir="$TERRAFORM_DIR" output -raw aws_region >/dev/null 2>&1; then
    REGION="$(terraform -chdir="$TERRAFORM_DIR" output -raw aws_region)"
  else
    REGION="us-east-1"
  fi
fi

cat <<SUMMARY
EKS cluster settings:
  cluster name: $CLUSTER_NAME
  region:       $REGION
  nodes:        $NODES
  node type:    $NODE_TYPE

This can create billable AWS resources.
SUMMARY

if [[ "$CONFIRM" != "true" ]]; then
  read -r -p "Continue? Type 'yes' to proceed: " answer
  if [[ "$answer" != "yes" ]]; then
    echo "Aborted."
    exit 1
  fi
fi

if eksctl get cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1; then
  echo "==> EKS cluster already exists; reusing it"
else
  echo "==> Creating EKS cluster"
  eksctl create cluster \
    --name "$CLUSTER_NAME" \
    --region "$REGION" \
    --nodes "$NODES" \
    --node-type "$NODE_TYPE" \
    --managed
fi

echo "==> Updating kubeconfig"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

echo "==> Cluster nodes"
kubectl get nodes -o wide