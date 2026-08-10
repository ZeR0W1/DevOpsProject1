#!/usr/bin/env bash
set -euo pipefail

# Create or update the complete three-service EKS-native CI pipeline job. This
# helper deliberately does not manage the legacy Docker-socket agent.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec bash "$PROJECT_ROOT/scripts/create_jenkins_job.sh" \
  --job-name "${JOB_NAME:-devops-project1-eks-pipeline}" \
  --jenkinsfile "${JENKINSFILE:-$PROJECT_ROOT/Jenkins/Jenkinsfile.eks}" \
  --description "EKS-native CI pipeline for frontend, backend, and worker" \
  --string-param REPO_URL "https://github.com/ZeR0W1/DevOpsProject1.git" "Git repository URL." \
  --string-param REPO_BRANCH "aws3-containerized" "Git branch, tag, or ref to build." \
  --string-param GIT_CREDENTIALS_ID "" "Optional Jenkins Git credential ID." \
  --string-param APP_DIR "Ansible-modules-01/roles/app/files/app" "Application path in the checked-out repository." \
  --string-param IMAGE_TAG "" "Optional shared image tag; default is BUILD_NUMBER-shortSHA." \
  --string-param DOCKERHUB_CREDENTIALS_ID "dockerhub-creds" "Jenkins username/password Docker Hub credential ID." \
  --boolean-param VALIDATE_ONLY false "Stop after source checks and Helm validation; do not build, push, or deploy images." \
  --boolean-param RUN_TRIVY_SCAN false "Run opt-in Trivy filesystem scan before image push." \
  --boolean-param DEPLOY_TO_EKS false "Trigger the standalone three-service CD job after all images are pushed." \
  --string-param CD_JOB_NAME "devops-project1-eks-deploy" "Standalone Jenkins CD job to trigger." \
  --string-param AWS_REGION "us-east-1" "AWS region containing the target EKS cluster." \
  --string-param EKS_CLUSTER_NAME "devops-app-eks" "Target EKS cluster name." \
  --string-param DEPLOY_NAMESPACE "devops-app" "Namespace containing application Helm releases." \
  --string-param FRONTEND_CONTENT_BUCKET "" "Terraform-owned application bucket containing index.html." \
  --string-param FRONTEND_CONTENT_KEY "index.html" "Stable S3 key used as the runtime frontend content source." \
  --boolean-param OVERWRITE_FRONTEND_CONTENT false "Replace existing S3 index.html with the repository default; missing content is always seeded." \
  --string-param WORKER_DB_HOST "" "Terraform RDS hostname passed to FULL CD runs." \
  --string-param WORKER_DB_PORT "5432" "Terraform RDS PostgreSQL port passed to FULL CD runs." \
  --string-param WORKER_DB_NAME "" "Terraform PostgreSQL database name passed to FULL CD runs." \
  --string-param WORKER_DB_USER "" "Terraform PostgreSQL username passed to FULL CD runs." \
  --string-param WORKER_DB_SECRET_NAME "worker-db-secret" "Existing Ansible-managed Kubernetes Secret name passed to FULL CD runs." \
  --string-param WORKER_S3_BUCKET "" "Terraform-owned bucket used for worker instances.json synchronization." \
  --string-param WORKER_SNS_TOPIC_ARN "" "Terraform-owned worker SNS topic ARN." \
  "$@"