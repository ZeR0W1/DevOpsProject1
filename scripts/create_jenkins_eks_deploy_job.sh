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
  --boolean-param CONFIRM_DEPLOY false "Required confirmation that this run may change EKS resources." \
  "$@"