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
  --string-param DEPLOY_NAMESPACE "devops-app" "Namespace containing application Helm releases." \
  "$@"