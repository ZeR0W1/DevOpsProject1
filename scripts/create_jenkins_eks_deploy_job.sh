#!/usr/bin/env bash
set -euo pipefail

# Convenience wrapper around the generic inline Pipeline job builder.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exec bash "$PROJECT_ROOT/scripts/create_jenkins_job.sh" \
  --job-name "${JOB_NAME:-devops-project1-eks-deploy}" \
  --jenkinsfile "${JENKINSFILE:-$PROJECT_ROOT/Jenkins/Jenkinsfile-deploy}" \
  --description "Standalone EKS Helm CD pipeline for frontend, backend, and worker" \
  --string-param REPO_URL "https://github.com/ZeR0W1/DevOpsProject1.git" "Repository containing all three application Helm charts." \
  --string-param REPO_REF "aws3-containerized" "Branch, tag, or commit containing the chart to deploy." \
  --string-param GIT_CREDENTIALS_ID "" "Optional Jenkins Git credential ID." \
  --string-param AWS_REGION "us-east-1" "AWS region containing EKS." \
  --string-param EKS_CLUSTER_NAME "devops-app-eks" "Target EKS cluster name." \
  --string-param FRONTEND_IMAGE_REPOSITORY "zer0w1/devops-project1-frontend" "Frontend image repository produced by CI." \
  --string-param BACKEND_IMAGE_REPOSITORY "zer0w1/devops-project1-backend" "Backend image repository produced by CI." \
  --string-param WORKER_IMAGE_REPOSITORY "zer0w1/devops-project1-worker" "Worker image repository produced by CI." \
  --string-param IMAGE_TAG "" "Required immutable tag shared by all three CI images; latest is rejected." \
  --string-param DEPLOY_NAMESPACE "devops-app" "Existing application namespace." \
  --string-param DEPLOY_MODE "FULL" "FULL deploys all workloads; CONTENT_ONLY synchronizes S3 index.html and restarts only frontend." \
  --string-param FRONTEND_CONTENT_BUCKET "" "Terraform-owned application bucket containing index.html." \
  --string-param FRONTEND_CONTENT_KEY "index.html" "Stable S3 key used as the runtime frontend content source." \
  --string-param WORKER_DB_HOST "" "Terraform RDS hostname for the worker." \
  --string-param WORKER_DB_PORT "5432" "Terraform RDS PostgreSQL port." \
  --string-param WORKER_DB_NAME "" "Terraform PostgreSQL database name." \
  --string-param WORKER_DB_USER "" "Terraform PostgreSQL administrator username." \
  --string-param WORKER_DB_SECRET_NAME "worker-db-secret" "Existing Ansible-managed Kubernetes Secret containing key password." \
  --string-param WORKER_S3_BUCKET "" "Terraform-owned bucket for worker instances.json synchronization." \
  --string-param WORKER_SNS_TOPIC_ARN "" "Terraform-owned SNS topic ARN for worker notifications." \
  --boolean-param CONFIRM_DEPLOY false "Required confirmation that this run may change EKS resources." \
  "$@"