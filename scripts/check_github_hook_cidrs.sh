#!/usr/bin/env bash
set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNAPSHOT="${PROJECT_ROOT}/config/github-hooks-applied.json"

if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  echo "NOTICE: Cannot verify GitHub webhook CIDRs (curl and jq are required)." >&2
  exit 2
fi

if [[ ! -f "${SNAPSHOT}" ]] || ! jq -e \
  '.schema_version == 1 and (.hooks_ipv4 | type == "array" and length > 0)' \
  "${SNAPSHOT}" >/dev/null 2>&1; then
  echo "NOTICE: Cannot verify GitHub webhook CIDRs (applied snapshot is invalid)." >&2
  exit 2
fi

if ! current_meta="$(curl --fail --silent --show-error \
  --connect-timeout 2 --max-time 5 https://api.github.com/meta 2>/dev/null)"; then
  echo "NOTICE: GitHub /meta is unavailable; push may continue and CI may still work." >&2
  exit 2
fi

if ! current="$(jq -cer \
  '[.hooks[] | select(contains(":") | not)] | unique | sort | select(length > 0)' \
  <<<"${current_meta}" 2>/dev/null)"; then
  echo "NOTICE: GitHub returned no valid webhook IPv4 ranges; unable to verify." >&2
  exit 2
fi

applied="$(jq -c '.hooks_ipv4 | unique | sort' "${SNAPSHOT}")"
if [[ "${current}" == "${applied}" ]]; then
  exit 0
fi

added="$(jq -r --argjson old "${applied}" '. - $old | join(", ")' <<<"${current}")"
removed="$(jq -r --argjson new "${current}" '. - $new | join(", ")' <<<"${applied}")"

echo "WARNING: GitHub webhook source ranges changed." >&2
echo "Push will continue, but Jenkins CI may wait for the ALB allowlist refresh." >&2
echo "Added:   ${added:-none}" >&2
echo "Removed: ${removed:-none}" >&2
echo "Recovery: bash setup.sh refresh-github-hooks" >&2
echo "After approval, the latest aws4-jenkins-cicd push is redelivered; CD remains manual." >&2
exit 3