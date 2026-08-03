#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade Jenkins and its least-privilege deployment identity for
# the temporary EKS lab. The chart creates a random admin Secret on first use.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALUES_FILE="$PROJECT_ROOT/Jenkins/values-eks.yaml"
DEPLOYER_RBAC_FILE="$PROJECT_ROOT/Jenkins/rbac-app-deployer.yaml"
CHART="oci://ghcr.io/jenkinsci/helm-charts/jenkins"
CHART_VERSION="5.8.114"
RELEASE_NAME="jenkins"
NAMESPACE="jenkins"
CLUSTER_NAME="${CLUSTER_NAME:-devops-app-eks}"
REGION="${AWS_REGION:-us-east-1}"
DEPLOYER_SERVICE_ACCOUNT="jenkins-deployer"
DEPLOYER_GROUP="jenkins-deployer"
ACTION="install"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Install, validate, or remove Jenkins from an already-configured Kubernetes
cluster. Installation also reconciles the Jenkins deployer IAM/Pod Identity,
EKS access entry, and namespace RBAC; it never changes local AWS credentials.

Options:
  --validate                 Render and validate manifests only; make no cluster changes.
  --uninstall                Remove the Helm release (the PVC is retained by default).
  --release-name NAME        Helm release name. Default: ${RELEASE_NAME}
  --namespace NAME           Kubernetes namespace. Default: ${NAMESPACE}
  --values PATH              Helm values file. Default: ${VALUES_FILE}
  --cluster-name NAME        EKS cluster name. Default: ${CLUSTER_NAME}
  --region REGION            AWS region. Default: ${REGION}
  -h, --help                 Show this help.

After installation, open Jenkins privately with:
  kubectl -n ${NAMESPACE} port-forward svc/${RELEASE_NAME} 18080:8080

Retrieve the generated initial admin password only when needed:
  kubectl -n ${NAMESPACE} exec ${RELEASE_NAME}-0 -c jenkins -- cat /run/secrets/additional/chart-admin-password; echo
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --validate) ACTION="validate"; shift ;;
    --uninstall) ACTION="uninstall"; shift ;;
    --release-name) RELEASE_NAME="${2:?Missing release name}"; shift 2 ;;
    --namespace) NAMESPACE="${2:?Missing namespace}"; shift 2 ;;
    --values) VALUES_FILE="${2:?Missing values path}"; shift 2 ;;
    --cluster-name) CLUSTER_NAME="${2:?Missing cluster name}"; shift 2 ;;
    --region) REGION="${2:?Missing region}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

for command_name in helm kubectl; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Required command not found: $command_name" >&2
    exit 127
  }
done
[[ -f "$VALUES_FILE" ]] || { echo "Values file not found: $VALUES_FILE" >&2; exit 1; }
[[ -f "$DEPLOYER_RBAC_FILE" ]] || { echo "RBAC file not found: $DEPLOYER_RBAC_FILE" >&2; exit 1; }

if [[ "$ACTION" == "validate" ]]; then
  helm template "$RELEASE_NAME" "$CHART" \
    --version "$CHART_VERSION" \
    --namespace "$NAMESPACE" \
    --values "$VALUES_FILE" \
    >/dev/null
  echo "Helm rendering succeeded for ${RELEASE_NAME} in namespace ${NAMESPACE}."
  exit 0
fi

if [[ "$ACTION" == "uninstall" ]]; then
  helm uninstall "$RELEASE_NAME" --namespace "$NAMESPACE"
  echo "Jenkins release removed. Review and delete its retained PVC manually when the lab is finished."
  exit 0
fi

kubectl cluster-info >/dev/null
helm upgrade --install "$RELEASE_NAME" "$CHART" \
  --version "$CHART_VERSION" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --values "$VALUES_FILE" \
  --wait \
  --timeout 15m

for command_name in aws jq; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Required command not found for Pod Identity setup: $command_name" >&2
    exit 127
  }
done

echo "==> Verifying EKS Pod Identity Agent"
ADDON_STATUS="$(aws eks describe-addon \
  --cluster-name "$CLUSTER_NAME" \
  --addon-name eks-pod-identity-agent \
  --region "$REGION" \
  --query 'addon.status' \
  --output text 2>/dev/null || true)"
[[ "$ADDON_STATUS" == "ACTIVE" ]] || {
  echo "EKS Pod Identity Agent is not ACTIVE. Run scripts/create_eks.sh first." >&2
  exit 1
}

echo "==> Applying Jenkins deployer ServiceAccount and namespace RBAC"
kubectl apply -f "$DEPLOYER_RBAC_FILE"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
DEPLOYER_ROLE_NAME="${CLUSTER_NAME}-jenkins-deployer"
DEPLOYER_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${DEPLOYER_ROLE_NAME}"
CLUSTER_ARN="arn:aws:eks:${REGION}:${ACCOUNT_ID}:cluster/${CLUSTER_NAME}"
TRUST_POLICY="$(mktemp)"
ROLE_POLICY="$(mktemp)"
cleanup_identity_files() { rm -f "$TRUST_POLICY" "$ROLE_POLICY"; }
trap cleanup_identity_files EXIT

jq -n '{
  Version: "2012-10-17",
  Statement: [{
    Effect: "Allow",
    Principal: {Service: "pods.eks.amazonaws.com"},
    Action: ["sts:AssumeRole", "sts:TagSession"]
  }]
}' > "$TRUST_POLICY"

jq -n --arg cluster_arn "$CLUSTER_ARN" '{
  Version: "2012-10-17",
  Statement: [{
    Effect: "Allow",
    Action: "eks:DescribeCluster",
    Resource: $cluster_arn
  }]
}' > "$ROLE_POLICY"

if aws iam get-role --role-name "$DEPLOYER_ROLE_NAME" >/dev/null 2>&1; then
  echo "==> Updating Jenkins deployer IAM role"
  aws iam update-assume-role-policy \
    --role-name "$DEPLOYER_ROLE_NAME" \
    --policy-document "file://${TRUST_POLICY}"
else
  echo "==> Creating Jenkins deployer IAM role"
  aws iam create-role \
    --role-name "$DEPLOYER_ROLE_NAME" \
    --assume-role-policy-document "file://${TRUST_POLICY}" \
    >/dev/null
fi
aws iam put-role-policy \
  --role-name "$DEPLOYER_ROLE_NAME" \
  --policy-name EKSDescribeCluster \
  --policy-document "file://${ROLE_POLICY}"

if aws eks describe-access-entry \
  --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$DEPLOYER_ROLE_ARN" \
  --region "$REGION" \
  >/dev/null 2>&1; then
  echo "==> Updating Jenkins deployer EKS access entry"
  aws eks update-access-entry \
    --cluster-name "$CLUSTER_NAME" \
    --principal-arn "$DEPLOYER_ROLE_ARN" \
    --kubernetes-groups "$DEPLOYER_GROUP" \
    --region "$REGION" \
    >/dev/null
else
  echo "==> Creating Jenkins deployer EKS access entry"
  ACCESS_ENTRY_CREATED=false
  for attempt in 1 2 3 4 5 6; do
    if aws eks create-access-entry \
      --cluster-name "$CLUSTER_NAME" \
      --principal-arn "$DEPLOYER_ROLE_ARN" \
      --type STANDARD \
      --kubernetes-groups "$DEPLOYER_GROUP" \
      --region "$REGION" \
      >/dev/null; then
      ACCESS_ENTRY_CREATED=true
      break
    fi
    if [[ "$attempt" -lt 6 ]]; then
      echo "IAM principal is not visible to EKS yet; retrying in 10 seconds (${attempt}/6)..." >&2
      sleep 10
    fi
  done
  [[ "$ACCESS_ENTRY_CREATED" == true ]] || {
    echo "Unable to create the Jenkins deployer EKS access entry after 6 attempts." >&2
    exit 1
  }
fi

ASSOCIATION_ID="$(aws eks list-pod-identity-associations \
  --cluster-name "$CLUSTER_NAME" \
  --namespace "$NAMESPACE" \
  --service-account "$DEPLOYER_SERVICE_ACCOUNT" \
  --region "$REGION" \
  --query 'associations[0].associationId' \
  --output text)"
if [[ -n "$ASSOCIATION_ID" && "$ASSOCIATION_ID" != "None" ]]; then
  echo "==> Updating Jenkins deployer Pod Identity association"
  aws eks update-pod-identity-association \
    --cluster-name "$CLUSTER_NAME" \
    --association-id "$ASSOCIATION_ID" \
    --role-arn "$DEPLOYER_ROLE_ARN" \
    --region "$REGION" \
    >/dev/null
else
  echo "==> Creating Jenkins deployer Pod Identity association"
  aws eks create-pod-identity-association \
    --cluster-name "$CLUSTER_NAME" \
    --namespace "$NAMESPACE" \
    --service-account "$DEPLOYER_SERVICE_ACCOUNT" \
    --role-arn "$DEPLOYER_ROLE_ARN" \
    --region "$REGION" \
    >/dev/null
fi

echo "==> Verifying Jenkins deployer RBAC"
RBAC_ALLOWED="$(kubectl auth can-i patch deployments \
  --namespace devops-app \
  --as-group "$DEPLOYER_GROUP" \
  --as "pod-identity-rbac-verification")"
[[ "$RBAC_ALLOWED" == "yes" ]] || {
  echo "Jenkins deployer RBAC verification failed." >&2
  exit 1
}

cat <<EOF_MESSAGE

Jenkins is installed as a private ClusterIP service.
Open it: kubectl -n ${NAMESPACE} port-forward svc/${RELEASE_NAME} 18080:8080
Retrieve its generated admin password only when needed:
  kubectl -n ${NAMESPACE} exec ${RELEASE_NAME}-0 -c jenkins -- cat /run/secrets/additional/chart-admin-password; echo

Jenkins deployment Pod Identity role:
  ${DEPLOYER_ROLE_ARN}

EOF_MESSAGE