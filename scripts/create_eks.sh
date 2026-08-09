#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

CLUSTER_NAME="devops-app-eks"
REGION=""
NODES=3
NODES_MAX=4
NODE_TYPE="t3.medium"
CONFIRM=false
EBS_CSI_SERVICE_ACCOUNT="ebs-csi-controller-sa"
EBS_CSI_NAMESPACE="kube-system"
POD_IDENTITY_ADDON="eks-pod-identity-agent"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Create or reuse an EKS cluster and update kubeconfig for kubectl/helm.

Options:
  --cluster-name NAME   EKS cluster name. Default: devops-app-eks
  --region REGION      AWS region. Default: Terraform aws_region output, then us-east-1
  --nodes COUNT        Managed node count. Default: 3
  --nodes-max COUNT    Managed node maximum. Default: 4
  --node-type TYPE     Managed node EC2 type. Default: t3.medium
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
    --nodes-max)
      NODES_MAX="${2:?Missing maximum node count}"
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
  nodes max:    $NODES_MAX
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
    --nodes-max "$NODES_MAX" \
    --node-type "$NODE_TYPE" \
    --managed
fi

EBS_CSI_ROLE_NAME="${CLUSTER_NAME}-ebs-csi-controller-role"

echo "==> Enabling OIDC for EKS service-account IAM roles"
eksctl utils associate-iam-oidc-provider \
  --cluster "$CLUSTER_NAME" \
  --region "$REGION" \
  --approve

echo "==> Ensuring dedicated EBS CSI controller IAM role"
eksctl create iamserviceaccount \
  --cluster "$CLUSTER_NAME" \
  --region "$REGION" \
  --namespace "$EBS_CSI_NAMESPACE" \
  --name "$EBS_CSI_SERVICE_ACCOUNT" \
  --role-name "$EBS_CSI_ROLE_NAME" \
  --attach-policy-arn "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy" \
  --approve \
  --override-existing-serviceaccounts

EBS_CSI_ROLE_ARN="$(aws iam get-role --role-name "$EBS_CSI_ROLE_NAME" --query 'Role.Arn' --output text)"

if aws eks describe-addon \
  --cluster-name "$CLUSTER_NAME" \
  --addon-name aws-ebs-csi-driver \
  --region "$REGION" \
  >/dev/null 2>&1; then
  echo "==> Updating EBS CSI add-on IAM association"
  aws eks update-addon \
    --cluster-name "$CLUSTER_NAME" \
    --addon-name aws-ebs-csi-driver \
    --service-account-role-arn "$EBS_CSI_ROLE_ARN" \
    --resolve-conflicts OVERWRITE \
    --region "$REGION" \
    >/dev/null
else
  echo "==> Installing EBS CSI add-on for persistent volumes"
  aws eks create-addon \
    --cluster-name "$CLUSTER_NAME" \
    --addon-name aws-ebs-csi-driver \
    --service-account-role-arn "$EBS_CSI_ROLE_ARN" \
    --resolve-conflicts OVERWRITE \
    --region "$REGION" \
    >/dev/null
fi

echo "==> Waiting for EBS CSI add-on"
aws eks wait addon-active \
  --cluster-name "$CLUSTER_NAME" \
  --addon-name aws-ebs-csi-driver \
  --region "$REGION"

if aws eks describe-addon \
  --cluster-name "$CLUSTER_NAME" \
  --addon-name "$POD_IDENTITY_ADDON" \
  --region "$REGION" \
  >/dev/null 2>&1; then
  echo "==> Updating EKS Pod Identity Agent add-on"
  aws eks update-addon \
    --cluster-name "$CLUSTER_NAME" \
    --addon-name "$POD_IDENTITY_ADDON" \
    --resolve-conflicts PRESERVE \
    --region "$REGION" \
    >/dev/null
else
  echo "==> Installing EKS Pod Identity Agent add-on"
  aws eks create-addon \
    --cluster-name "$CLUSTER_NAME" \
    --addon-name "$POD_IDENTITY_ADDON" \
    --resolve-conflicts PRESERVE \
    --region "$REGION" \
    >/dev/null
fi

echo "==> Waiting for EKS Pod Identity Agent add-on"
aws eks wait addon-active \
  --cluster-name "$CLUSTER_NAME" \
  --addon-name "$POD_IDENTITY_ADDON" \
  --region "$REGION"

echo "==> Updating kubeconfig"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

echo "==> Cluster nodes"
kubectl get nodes -o wide