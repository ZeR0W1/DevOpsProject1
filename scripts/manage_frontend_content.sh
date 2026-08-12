#!/usr/bin/env sh
set -eu

MAX_CONFIGMAP_BYTES=900000

usage() {
  command_name=$(basename "$0")
  echo "Usage: $command_name COMMAND ARGUMENTS..." >&2
  echo "  validate FILE" >&2
  echo "  seed FILE BUCKET KEY OVERWRITE REGION" >&2
  echo "  sync FILE BUCKET KEY REGION NAMESPACE CONFIGMAP" >&2
  echo "  verify FILE NAMESPACE CONFIGMAP DEPLOYMENT TIMEOUT_SECONDS" >&2
  exit 2
}

fail() {
  echo "$*" >&2
  exit 1
}

validate_html() {
  file=$1

  [ -s "$file" ] || fail "Frontend HTML is empty or missing: $file"

  size=$(wc -c < "$file" | tr -d ' ')
  [ "$size" -le "$MAX_CONFIGMAP_BYTES" ] || fail \
    "Frontend HTML exceeds the ${MAX_CONFIGMAP_BYTES}-byte ConfigMap safety limit."

  grep -Eiq '<[[:space:]]*!doctype[[:space:]]+html|<[[:space:]]*html([[:space:]>])' "$file" || {
    fail "Frontend content does not appear to be an HTML document."
  }

  sha256sum "$file" | awk '{print $1}'
}

case "${1:-}" in
  validate)
    [ "$#" -eq 2 ] || usage
    validate_html "$2"
    ;;
  seed)
    [ "$#" -eq 6 ] || usage
    file=$2 bucket=$3 key=$4 overwrite=$5 region=$6
    checksum=$(validate_html "$file")
    if metadata=$(aws s3api head-object \
      --bucket "$bucket" --key "$key" --region "$region" 2>&1); then
      if [ "$overwrite" = "true" ]; then
        action=overwrite
      else
        echo "Preserving existing s3://${bucket}/${key}; default SHA-256=${checksum}."
        exit 0
      fi
    else
      status=$?
      case "$metadata" in
        *Not\ Found*|*404*) action=seed ;;
        *) printf '%s\n' "$metadata" >&2; exit "$status" ;;
      esac
    fi
    result=$(aws s3api put-object \
      --bucket "$bucket" --key "$key" --body "$file" \
      --content-type text/html --region "$region" \
      --query '[ETag,VersionId]' --output text)
    set -- $result
    etag=${1:-unknown} version=${2:-unversioned}
    [ "$version" != None ] || version=unversioned
    echo "Frontend content ${action}: s3://${bucket}/${key}"
    echo "SHA-256=${checksum}, ETag=${etag}, VersionId=${version}"
    ;;
  sync)
    [ "$#" -eq 7 ] || usage
    file=$2 bucket=$3 key=$4 region=$5 namespace=$6 configmap=$7
    aws s3api get-object \
      --bucket "$bucket" --key "$key" --region "$region" "$file" >/dev/null
    checksum=$(validate_html "$file")
    kubectl create configmap "$configmap" --namespace "$namespace" \
      --from-file=index.html="$file" --dry-run=client -o yaml \
      | kubectl label --local -f - app.kubernetes.io/managed-by=jenkins-cd -o yaml \
      | kubectl annotate --local -f - \
          devops.project1/content-sha256="$checksum" -o yaml \
      | kubectl apply -f -
    echo "$checksum"
    ;;
  verify)
    [ "$#" -eq 6 ] || usage
    file=$2 namespace=$3 configmap=$4 deployment=$5 timeout=$6
    checksum=$(validate_html "$file")
    applied=$(kubectl get configmap "$configmap" --namespace "$namespace" \
      -o go-template='{{ index .data "index.html" }}' \
      | sha256sum | awk '{print $1}')
    [ "$applied" = "$checksum" ] || fail \
      "ConfigMap checksum does not match downloaded S3 content."
    kubectl rollout restart "deployment/${deployment}" --namespace "$namespace"
    kubectl rollout status "deployment/${deployment}" \
      --namespace "$namespace" --timeout="${timeout}s"
    echo "ConfigMap and restarted frontend Deployment use SHA-256 ${checksum}."
    ;;
  *) usage ;;
esac