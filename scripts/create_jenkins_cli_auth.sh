#!/usr/bin/env bash
set -euo pipefail

# Create a Jenkins CLI auth file in the format required by:
#   java -jar jenkins-cli.jar -s <JENKINS_URL> -http -auth @<AUTH_FILE> <command>
#
# The script prompts for the API token without echoing it to the terminal,
# writes USERNAME:TOKEN to the auth file, and locks the file permissions to 600.

DEFAULT_AUTH_FILE="${HOME}/.jenkins-cli-auth"
DEFAULT_USERNAME="admin"

USERNAME="${1:-${DEFAULT_USERNAME}}"
AUTH_FILE="${2:-${DEFAULT_AUTH_FILE}}"

if [[ -z "${USERNAME}" ]]; then
    echo "Username cannot be empty." >&2
    exit 1
fi

read -r -s -p "Enter Jenkins API token for user '${USERNAME}': " API_TOKEN
echo

if [[ -z "${API_TOKEN}" ]]; then
    echo "API token cannot be empty." >&2
    exit 1
fi

umask 077
mkdir -p "$(dirname "${AUTH_FILE}")"
printf '%s:%s\n' "${USERNAME}" "${API_TOKEN}" > "${AUTH_FILE}"
chmod 600 "${AUTH_FILE}"

echo "Created Jenkins CLI auth file: ${AUTH_FILE}"
echo "Permissions set to 600. Use it with:"
echo "  java -jar jenkins-cli.jar -s <JENKINS_URL> -http -auth @${AUTH_FILE} <command>"