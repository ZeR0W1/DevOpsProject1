#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
FRONTEND_CHART_DIR="$PROJECT_ROOT/helm/frontend"
BACKEND_CHART_DIR="$PROJECT_ROOT/helm/backend"
WORKER_CHART_DIR="$PROJECT_ROOT/helm/worker"
FRONTEND_SOURCE_HTML="$PROJECT_ROOT/Ansible-modules-01/roles/app/files/app/src/frontend/index2.html"
FRONTEND_CHART_HTML="$FRONTEND_CHART_DIR/files/index.html"
NAMESPACE="devops-app"

echo "==> Reading Terraform outputs"
TF_JSON="$(terraform -chdir="$TERRAFORM_DIR" output -json)"

RDS_HOSTNAME="$(printf '%s' "$TF_JSON" | jq -r '.rds_hostname.value')"
DB_PORT="$(printf '%s' "$TF_JSON" | jq -r '.db_port.value')"
DB_NAME="$(printf '%s' "$TF_JSON" | jq -r '.db_name.value')"
DB_USERNAME="$(printf '%s' "$TF_JSON" | jq -r '.db_username.value')"
AWS_REGION="$(printf '%s' "$TF_JSON" | jq -r '.aws_region.value')"
S3_BUCKET_NAME="$(printf '%s' "$TF_JSON" | jq -r '.s3_bucket_name.value')"
SNS_TOPIC_ARN="$(printf '%s' "$TF_JSON" | jq -r '.sns_topic_arn.value')"
DB_PASSWORD_SECRET_NAME="$(printf '%s' "$TF_JSON" | jq -r '.db_password_secret_name.value')"

echo "==> Syncing frontend HTML into chart files"
cp "$FRONTEND_SOURCE_HTML" "$FRONTEND_CHART_HTML"

if [[ -z "${WORKER_DB_PASSWORD:-}" ]]; then
  echo "==> Reading Terraform-generated DB password from AWS Secrets Manager: $DB_PASSWORD_SECRET_NAME"
  WORKER_DB_PASSWORD="$(aws secretsmanager get-secret-value \
    --region "$AWS_REGION" \
    --secret-id "$DB_PASSWORD_SECRET_NAME" \
    --query SecretString \
    --output text)"
else
  echo "==> Using DB password from WORKER_DB_PASSWORD environment variable override"
fi

echo "==> Ensuring Kubernetes namespace exists: $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Creating/updating worker DB secret"
kubectl create secret generic worker-db-secret \
  --namespace "$NAMESPACE" \
  --from-literal=password="$WORKER_DB_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Deploying frontend chart"
helm upgrade --install frontend "$FRONTEND_CHART_DIR" \
  --namespace "$NAMESPACE" \
  -f "$FRONTEND_CHART_DIR/values.yaml"

echo "==> Deploying backend chart"
helm upgrade --install backend "$BACKEND_CHART_DIR" \
  --namespace "$NAMESPACE" \
  -f "$BACKEND_CHART_DIR/values.yaml"

echo "==> Deploying worker chart"
helm upgrade --install worker "$WORKER_CHART_DIR" \
  --namespace "$NAMESPACE" \
  -f "$WORKER_CHART_DIR/values.yaml" \
  --set database.host="$RDS_HOSTNAME" \
  --set database.port="$DB_PORT" \
  --set database.name="$DB_NAME" \
  --set database.user="$DB_USERNAME" \
  --set aws.region="$AWS_REGION" \
  --set aws.s3BucketName="$S3_BUCKET_NAME" \
  --set aws.snsTopicArn="$SNS_TOPIC_ARN"

echo "==> Kubernetes deployment flow completed"