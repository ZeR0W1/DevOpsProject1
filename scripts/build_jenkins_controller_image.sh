#!/usr/bin/env bash
set -euo pipefail

# Build the pinned Jenkins controller image used by the EKS Helm deployment.
# Authenticate Docker Hub separately with `docker login` before using --push;
# this script never accepts, records, or prints Docker Hub credentials.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_IMAGE="zer0w1/devops-project1-jenkins-controller:2.528.3-jdk21-plugins-v2"
IMAGE="$DEFAULT_IMAGE"
PUSH=false

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Build the pinned Jenkins controller image from Jenkins/Dockerfile.controller.

Options:
  --image IMAGE    Docker image reference. Default: ${DEFAULT_IMAGE}
  --push            Push after a successful build; requires prior docker login.
  -h, --help        Show this help.

Examples:
  $(basename "$0")
  docker login
  $(basename "$0") --push
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE="${2:?Missing image reference}"; shift 2 ;;
    --push) PUSH=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

command -v docker >/dev/null 2>&1 || {
  echo "Required command not found: docker" >&2
  exit 127
}

docker build \
  --file "$PROJECT_ROOT/Jenkins/Dockerfile.controller" \
  --tag "$IMAGE" \
  "$PROJECT_ROOT/Jenkins"

printf 'Built Jenkins controller image: %s\n' "$IMAGE"

if [[ "$PUSH" == true ]]; then
  docker push "$IMAGE"
  printf 'Pushed Jenkins controller image: %s\n' "$IMAGE"
else
  echo 'Image was not pushed. Run with --push after interactive docker login to publish it.'
fi