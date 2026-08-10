#!/usr/bin/env sh
set -eu

usage() {
  echo "Usage: $(basename "$0") validate FILE | seed FILE BUCKET KEY OVERWRITE REGION | sync FILE BUCKET KEY REGION NAMESPACE CONFIGMAP | verify FILE NAMESPACE CONFIGMAP DEPLOYMENT TIMEOUT_SECONDS" >&2
  exit 2
}

validate_html() {
  file=$1
  [ -s "$file" ] || { echo "Frontend HTML is empty or missing: $file" >&2; exit 1; }
  size=$(wc -c < "$file" | tr -d ' ')
  [ "$size" -le 900000 ] || { echo "Frontend HTML exceeds the 900000-byte ConfigMap safety limit." >&2; exit 1; }
  grep -Eiq '<[[:space:]]*!doctype[[:space:]]+html|<[[:space:]]*html([[:space:]>])' "$file" || {
    echo "Frontend content does not appear to be an HTML document." >&2
    exit 1
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
    if metadata=$(aws s3api head-object --bucket "$bucket" --key "$key" --region "$region" 2>&1); then
      if [ "$overwrite" = "true" ]; then
        action=overwrite
      else
        echo "Preserving existing s3://${bucket}/${key}; SHA-256 of repository default is ${checksum}."
        exit 0
      fi
    else
      status=$?
      case "$metadata" in
        *Not\ Found*|*404*) action=seed ;;
        *) printf '%s\n' "$metadata" >&2; exit "$status" ;;
      esac
    fi
    result=$(aws s3api put-object --bucket "$bucket" --key "$key" --body "$file" \
      --content-type text/html --region "$region" --query '[ETag,VersionId]' --output text)
    set -- $result
    etag=${1:-unknown}
    version=${2:-unversioned}
    [ "$version" != None ] || version=unversioned
    echo "Frontend content ${action} complete: s3://${bucket}/${key}, SHA-256=${checksum}, ETag=${etag}, VersionId=${version}."
    ;;
  sync)
    [ "$#" -eq 7 ] || usage
    file=$2 bucket=$3 key=$4 region=$5 namespace=$6 configmap=$7
    aws s3api get-object --bucket "$bucket" --key "$key" --region "$region" "$file" >/dev/null
    checksum=$(validate_html "$file")
    kubectl create configmap "$configmap" --namespace "$namespace" \
      --from-file=index.html="$file" --dry-run=client -o yaml \
      | kubectl label --local -f - app.kubernetes.io/managed-by=jenkins-cd \
          -o yaml \
      | kubectl annotate --local -f - devops.project1/content-sha256="$checksum" \
          -o yaml \
      | kubectl apply -f -
    echo "$checksum"
    ;;
  verify)
    [ "$#" -eq 6 ] || usage
    file=$2 namespace=$3 configmap=$4 deployment=$5 timeout=$6
    checksum=$(validate_html "$file")
    applied=$(kubectl get configmap "$configmap" --namespace "$namespace" \
      -o go-template='{{ index .data "index.html" }}' | sha256sum | awk '{print $1}')
    [ "$applied" = "$checksum" ] || { echo "ConfigMap checksum does not match downloaded S3 content." >&2; exit 1; }
    kubectl rollout restart "deployment/${deployment}" --namespace "$namespace"
    kubectl rollout status "deployment/${deployment}" --namespace "$namespace" --timeout="${timeout}s"
    echo "ConfigMap and restarted frontend Deployment use SHA-256 ${checksum}."
    ;;
  *) usage ;;
esac