#!/usr/bin/env bash

# Archived local-Docker Jenkins lab helper. It is not part of the supported EKS
# lifecycle; use scripts/create_jenkins_eks_pipeline_job.sh for current CI.
# It is intentionally written as a plain Bash script so you can read it,
# change values, and learn what each Jenkins CLI / Docker command does.

# Safer Bash settings:
# -e: stop immediately if a command fails
# -u: fail if we use an undefined variable
# -o pipefail: fail a pipeline if any command inside it fails
set -euo pipefail

# Create or update a Jenkins Pipeline job using Jenkins CLI.
# Also creates/updates the inbound Jenkins agent node required by the pipeline
# label, then starts the Docker container that connects that agent.
#
# Defaults are tailored to this repository. Every value below can be overridden
# either with an environment variable or with a command-line option.
# Example:
#   JOB_NAME=my-test-job ./scripts/create_jenkins_pipeline_job.sh

# Jenkins controller URL.
JENKINS_URL="${JENKINS_URL:-http://127.0.0.1:8080/}"

# Name of the Pipeline job that will appear in Jenkins.
JOB_NAME="${JOB_NAME:-devops-project1-pipeline}"

# Name of the Jenkins agent node this script creates/updates.
NODE_NAME="${NODE_NAME:-docker-builder-1}"

# Labels assigned to the node. The Jenkinsfile waits for a node with this label.
NODE_LABELS="${NODE_LABELS:-docker-builder}"

# Workspace/root directory Jenkins will use inside the agent container.
REMOTE_FS="${REMOTE_FS:-/home/jenkins/agent}"

# Number of builds this node can run at the same time. 1 is safest for Docker builds.
EXECUTORS="${EXECUTORS:-1}"

# Local Docker image used to start the Jenkins agent container.
AGENT_IMAGE="${AGENT_IMAGE:-devops-project1-jenkins-agent:latest}"

# Whether this script should start a local SonarQube container for the pipeline.
# The Jenkins SonarQube plugin still needs to be configured in Jenkins after this.
START_SONARQUBE="${START_SONARQUBE:-true}"

# Docker image/container/port used for the local SonarQube server.
SONARQUBE_IMAGE="${SONARQUBE_IMAGE:-sonarqube:community}"
SONARQUBE_CONTAINER="${SONARQUBE_CONTAINER:-sonarqube}"
SONARQUBE_PORT="${SONARQUBE_PORT:-9000}"

# URL Jenkins should use to reach SonarQube. For this machine's current setup,
# the Tailscale/VPN-looking IP is usually better than localhost because Jenkins
# and agents may be containers or remote processes.
SONARQUBE_URL="${SONARQUBE_URL:-http://127.0.0.1:${SONARQUBE_PORT}}"

# Host-only address used when this script initializes the container it just
# created. Do not use SONARQUBE_URL for this: its default is Jenkins-facing
# and can be a VPN/Tailscale address that does not loop back to this host.
SONARQUBE_BOOTSTRAP_URL="${SONARQUBE_BOOTSTRAP_URL:-http://127.0.0.1:${SONARQUBE_PORT}}"

# A brand-new SonarQube server always starts with this built-in account.
# Keep it fixed: a different user does not exist during bootstrap.
SONARQUBE_USER="admin"
SONARQUBE_TOKEN_NAME="${SONARQUBE_TOKEN_NAME:-jenkins-token}"

# Jenkins resources managed when this script creates a new SonarQube server.
# The installation name must match the Jenkinsfile's SONARQUBE_ENV default.
SONARQUBE_JENKINS_INSTALLATION="${SONARQUBE_JENKINS_INSTALLATION:-SonarQube}"
SONARQUBE_CREDENTIALS_ID="${SONARQUBE_CREDENTIALS_ID:-sonar-token}"

# Runtime-only variables. The script may set these while it runs, but it does
# not write the SonarQube password to disk.
SONARQUBE_CREATED=false
SONARQUBE_PASSWORD=""
SONARQUBE_TOKEN=""


# Whether this script should start the Docker agent container automatically.
START_AGENT="${START_AGENT:-true}"

# If a stopped container with NODE_NAME already exists, remove and recreate it.
REPLACE_AGENT_CONTAINER="${REPLACE_AGENT_CONTAINER:-true}"

# Jenkins CLI jar used to call Jenkins commands from this machine.
CLI_JAR="${CLI_JAR:-Jenkins/jenkins-cli.jar}"

# Temporary auth file for Jenkins CLI. It is deleted by cleanup() at the end.
AUTH_FILE="${AUTH_FILE:-${HOME}/.jenkins-cli-auth}"

# Jenkins username used when creating the temporary auth file.
AUTH_USERNAME="${AUTH_USERNAME:-admin}"

# Helper script that securely prompts for an API token and writes AUTH_FILE.
AUTH_SCRIPT="${AUTH_SCRIPT:-scripts/create_jenkins_cli_auth.sh}"

# Jenkinsfile that will be embedded into the Pipeline job config XML.
JENKINSFILE="${JENKINSFILE:-Jenkins/legacy/local-docker/Jenkinsfile}"

# Optional output path for generated job XML. If empty, a temp file is used.
JOB_CONFIG="${JOB_CONFIG:-}"

usage() {
    # Show help text. This runs when you pass --help.
    cat <<USAGE
Usage: $0 [options]

Options:
  -u, --url URL             Jenkins URL. Default: ${JENKINS_URL}
  -n, --name JOB_NAME       Jenkins job name. Default: ${JOB_NAME}
  --node-name NODE_NAME     Jenkins inbound agent node name. Default: ${NODE_NAME}
  --node-labels LABELS      Jenkins node labels. Default: ${NODE_LABELS}
  --remote-fs PATH          Agent remote FS root. Default: ${REMOTE_FS}
  --executors COUNT         Agent executor count. Default: ${EXECUTORS}
  --agent-image IMAGE       Docker agent image for printed run command. Default: ${AGENT_IMAGE}
  --start-sonarqube true|false Start local SonarQube container. Default: ${START_SONARQUBE}
  --sonarqube-image IMAGE   SonarQube Docker image. Default: ${SONARQUBE_IMAGE}
  --sonarqube-container NAME SonarQube container name. Default: ${SONARQUBE_CONTAINER}
  --sonarqube-port PORT     Host port for SonarQube. Default: ${SONARQUBE_PORT}
  --sonarqube-url URL       URL Jenkins should use for SonarQube. Default: ${SONARQUBE_URL}
  --sonarqube-token-name NAME SonarQube token name. Default: ${SONARQUBE_TOKEN_NAME}
  --sonarqube-installation NAME Jenkins SonarQube installation name. Default: ${SONARQUBE_JENKINS_INSTALLATION}
  --sonarqube-credentials-id ID Jenkins credential ID for the SonarQube token. Default: ${SONARQUBE_CREDENTIALS_ID}
  --start-agent true|false  Start Docker agent container. Default: ${START_AGENT}
  --replace-agent true|false Remove existing same-name agent container first. Default: ${REPLACE_AGENT_CONTAINER}
  -j, --jar PATH            Jenkins CLI jar path. Default: ${CLI_JAR}
  -a, --auth PATH           Jenkins CLI auth file. Default: ${AUTH_FILE}
  --auth-user USER          Jenkins username for API token prompt. Default: ${AUTH_USERNAME}
  --auth-script PATH        Auth helper script path. Default: ${AUTH_SCRIPT}
  -f, --file PATH           Jenkinsfile path. Default: ${JENKINSFILE}
  -c, --config PATH         Optional path to write/generated job config XML.
  -h, --help                Show this help.

Environment variable equivalents:
  JENKINS_URL, JOB_NAME, NODE_NAME, NODE_LABELS, REMOTE_FS, EXECUTORS,
  AGENT_IMAGE, START_SONARQUBE, SONARQUBE_IMAGE, SONARQUBE_CONTAINER,
  SONARQUBE_PORT, SONARQUBE_URL, SONARQUBE_TOKEN_NAME,
  SONARQUBE_JENKINS_INSTALLATION, SONARQUBE_CREDENTIALS_ID, START_AGENT,
  REPLACE_AGENT_CONTAINER,
  CLI_JAR, AUTH_FILE, AUTH_USERNAME, AUTH_SCRIPT, JENKINSFILE, JOB_CONFIG

Examples:
  ./scripts/create_jenkins_pipeline_job.sh

  JOB_NAME=my-pipeline \\
  JENKINS_URL=http://127.0.0.1:8080/ \\
  ./scripts/create_jenkins_pipeline_job.sh
USAGE
}

while [[ $# -gt 0 ]]; do
    # Parse command-line options. Each option usually consumes itself and
    # the value after it, so we use "shift 2".
    case "$1" in
        -u|--url)
            JENKINS_URL="$2"
            shift 2
            ;;
        -n|--name)
            JOB_NAME="$2"
            shift 2
            ;;
        --node-name)
            NODE_NAME="$2"
            shift 2
            ;;
        --node-labels)
            NODE_LABELS="$2"
            shift 2
            ;;
        --remote-fs)
            REMOTE_FS="$2"
            shift 2
            ;;
        --executors)
            EXECUTORS="$2"
            shift 2
            ;;
        --agent-image)
            AGENT_IMAGE="$2"
            shift 2
            ;;
        --start-sonarqube)
            START_SONARQUBE="$2"
            shift 2
            ;;
        --sonarqube-image)
            SONARQUBE_IMAGE="$2"
            shift 2
            ;;
        --sonarqube-container)
            SONARQUBE_CONTAINER="$2"
            shift 2
            ;;
        --sonarqube-port)
            SONARQUBE_PORT="$2"
            shift 2
            ;;
        --sonarqube-url)
            SONARQUBE_URL="$2"
            shift 2
            ;;
        --sonarqube-token-name)
            SONARQUBE_TOKEN_NAME="$2"
            shift 2
            ;;
        --sonarqube-installation)
            SONARQUBE_JENKINS_INSTALLATION="$2"
            shift 2
            ;;
        --sonarqube-credentials-id)
            SONARQUBE_CREDENTIALS_ID="$2"
            shift 2
            ;;
        --start-agent)
            START_AGENT="$2"
            shift 2
            ;;
        --replace-agent)
            REPLACE_AGENT_CONTAINER="$2"
            shift 2
            ;;
        -j|--jar)
            CLI_JAR="$2"
            shift 2
            ;;
        -a|--auth)
            AUTH_FILE="$2"
            shift 2
            ;;
        --auth-user)
            AUTH_USERNAME="$2"
            shift 2
            ;;
        --auth-script)
            AUTH_SCRIPT="$2"
            shift 2
            ;;
        -f|--file)
            JENKINSFILE="$2"
            shift 2
            ;;
        -c|--config)
            JOB_CONFIG="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

require_file() {
    # Small helper function to fail early with a friendly message if a required
    # file is missing.
    local path="$1"
    local description="$2"
    if [[ ! -f "${path}" ]]; then
        echo "Missing ${description}: ${path}" >&2
        exit 1
    fi
}

require_file "${CLI_JAR}" "Jenkins CLI jar"
require_file "${AUTH_SCRIPT}" "Jenkins CLI auth helper script"
require_file "${JENKINSFILE}" "Jenkinsfile"

xml_escape() {
    # XML cannot contain raw &, <, >, or " characters in certain places.
    # This function converts those characters to XML-safe entities.
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

groovy_string_escape() {
    # Escape the two characters that could break the quoted Groovy string used
    # to look up the Jenkins node below.
    sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

groovy_single_quote_escape() {
    # Safely insert an external value into a single-quoted Groovy string.
    sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g"
}

wait_for_http() {
    # Wait until a web service responds. SonarQube can take a minute or two to
    # start the first time because it initializes its internal database/indexes.
    local url="$1"
    local name="$2"
    local max_attempts="$3"

    for attempt in $(seq 1 "${max_attempts}"); do
        if curl -fsS "${url}" >/dev/null 2>&1; then
            echo "${name} is responding at ${url}"
            return 0
        fi
        echo "Waiting for ${name} (${attempt}/${max_attempts})..."
        sleep 5
    done

    echo "Timed out waiting for ${name} at ${url}" >&2
    return 1
}

prompt_for_new_sonarqube_password() {
    # Ask until the new password is confirmed and meets the basic server policy.
    local password password_confirm

    while true; do
        read -r -s -p "Enter NEW SonarQube password for '${SONARQUBE_USER}': " password
        echo >&2
        read -r -s -p "Confirm NEW SonarQube password for '${SONARQUBE_USER}': " password_confirm
        echo >&2

        if [[ -z "${password}" ]]; then
            echo "Password cannot be empty. Please try again." >&2
            continue
        fi
        if [[ ${#password} -lt 12 ]]; then
            echo "Password must be at least 12 characters long. Please try again." >&2
            continue
        fi
        if [[ "${password}" != "${password_confirm}" ]]; then
            echo "Passwords do not match. Please try again." >&2
            continue
        fi
        if [[ ! "${password}" =~ [A-Z] ]] || [[ ! "${password}" =~ [a-z] ]] || [[ ! "${password}" =~ [0-9] ]] || [[ ! "${password}" =~ [^[:alnum:]] ]]; then
            echo "Password must contain uppercase, lowercase, numeric, and special characters. Please try again." >&2
            continue
        fi

        printf '%s' "${password}"
        return 0
    done
}

initialize_fresh_sonarqube_password() {
    # A brand-new SonarQube container starts with admin/admin.
    # We prompt you for the new admin password, then change admin/admin to that
    # password through the SonarQube API. The password is not stored on disk.
    if [[ "${SONARQUBE_CREATED}" != "true" ]]; then
        return 0
    fi

    local response status body
    echo "Fresh SonarQube container was created. Initializing admin password."

    while true; do
        SONARQUBE_PASSWORD="$(prompt_for_new_sonarqube_password)"

        if ! response="$(curl -sS -u "${SONARQUBE_USER}:admin" \
            -X POST \
            --data-urlencode "login=${SONARQUBE_USER}" \
            --data-urlencode 'previousPassword=admin' \
            --data-urlencode "password=${SONARQUBE_PASSWORD}" \
            -w '\n%{http_code}' \
            "${SONARQUBE_BOOTSTRAP_URL}/api/users/change_password")"; then
            echo "Unable to contact SonarQube while changing the admin password." >&2
            return 1
        fi

        status="${response##*$'\n'}"
        body="${response%$'\n'*}"
        if [[ "${status}" == "204" ]]; then
            echo "SonarQube admin password changed for user '${SONARQUBE_USER}'."
            return 0
        fi

        echo "SonarQube rejected the new admin password (HTTP ${status}): ${body}" >&2
        if [[ "${status}" != "400" ]]; then
            echo "This is not a password-policy rejection; stopping bootstrap instead of retrying." >&2
            return 1
        fi
        echo "Please choose a different password." >&2
    done
}

create_sonarqube_token() {
    # Create the one Jenkins analysis token required during fresh-server setup.
    # The new admin password is already in memory from initialization, so no
    # additional password prompt or host-side password storage is needed.
    local response token

    if [[ -z "${SONARQUBE_PASSWORD}" ]]; then
        echo "Cannot create the initial SonarQube token without an in-memory bootstrap password." >&2
        return 1
    fi

    echo "Creating SonarQube token '${SONARQUBE_TOKEN_NAME}' for user '${SONARQUBE_USER}'"
    response="$(curl -fsS -u "${SONARQUBE_USER}:${SONARQUBE_PASSWORD}" \
        -X POST \
        --data-urlencode "name=${SONARQUBE_TOKEN_NAME}" \
        "${SONARQUBE_BOOTSTRAP_URL}/api/user_tokens/generate")"

    token="$(printf '%s' "${response}" | jq -r '.token // empty')"
    if [[ -z "${token}" ]]; then
        echo "SonarQube token creation did not return a token. Raw response:" >&2
        printf '%s\n' "${response}" >&2
        return 1
    fi

    SONARQUBE_TOKEN="${token}"

    echo
    echo "Created SonarQube token. Copy it now; SonarQube will not show it again:"
    echo "${token}"
    echo
    echo "Use this token in Jenkins → Manage Jenkins → System → SonarQube servers."
}

register_sonarqube_in_jenkins() {
    # Register the server that this script just created. The SonarQube Scanner
    # for Jenkins plugin uses this named installation for withSonarQubeEnv().
    # Values are passed in the CLI script input, not command arguments, so the
    # token is not exposed in a process command line.
    if [[ -z "${SONARQUBE_TOKEN}" ]]; then
        echo "Cannot register SonarQube in Jenkins without the newly created token." >&2
        return 1
    fi

    echo "Registering SonarQube installation '${SONARQUBE_JENKINS_INSTALLATION}' in Jenkins."
    local groovy_name groovy_url groovy_credential_id groovy_token
    groovy_name="$(printf '%s' "${SONARQUBE_JENKINS_INSTALLATION}" | groovy_single_quote_escape)"
    groovy_url="$(printf '%s' "${SONARQUBE_URL}" | groovy_single_quote_escape)"
    groovy_credential_id="$(printf '%s' "${SONARQUBE_CREDENTIALS_ID}" | groovy_single_quote_escape)"
    groovy_token="$(printf '%s' "${SONARQUBE_TOKEN}" | groovy_single_quote_escape)"

    {
        cat <<GROOVY_HEAD
import com.cloudbees.plugins.credentials.CredentialsProvider
import com.cloudbees.plugins.credentials.SystemCredentialsProvider
import com.cloudbees.plugins.credentials.domains.Domain
import hudson.plugins.sonar.SonarGlobalConfiguration
import hudson.plugins.sonar.SonarInstallation
import hudson.util.Secret
import jenkins.model.Jenkins
import org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl

def name = '${groovy_name}'
def serverUrl = '${groovy_url}'
def credentialId = '${groovy_credential_id}'
def token = '${groovy_token}'
GROOVY_HEAD
        cat <<'GROOVY_BODY'

def credentialsStore = SystemCredentialsProvider.getInstance().getStore()
def existingCredential = CredentialsProvider.lookupCredentials(
    StringCredentialsImpl.class, Jenkins.instance, null, null
).find { it.id == credentialId }
if (existingCredential != null) {
    credentialsStore.removeCredentials(Domain.global(), existingCredential)
}
credentialsStore.addCredentials(
    Domain.global(),
    new StringCredentialsImpl(
        com.cloudbees.plugins.credentials.CredentialsScope.GLOBAL,
        credentialId,
        "Managed SonarQube token for ${name}",
        Secret.fromString(token)
    )
)

def configuration = SonarGlobalConfiguration.get()
def installations = configuration.getInstallations().findAll { it.name != name }
// Verified from the installed SonarQube Scanner for Jenkins 2.18.3 class:
// (name, serverUrl, serverAuthenticationToken, mojoVersion,
//  additionalProperties, TriggersConfig, sonarScannerName). The third
// argument is the token itself, not a Jenkins credentials ID.
installations.add(new SonarInstallation(name, serverUrl, token, '', '', null, ''))
configuration.setInstallations(installations as SonarInstallation[])
configuration.save()
println "Registered Jenkins SonarQube installation: ${name}"
GROOVY_BODY
    } | java -jar "${CLI_JAR}" \
        -s "${JENKINS_URL}" \
        -http \
        -auth "@${AUTH_FILE}" \
        groovy =
}

remove_failed_fresh_sonarqube() {
    # Only remove a container this invocation created. Never remove a server
    # that existed before the script started.
    if [[ "${SONARQUBE_CREATED}" != "true" ]]; then
        return 0
    fi

    echo "Initial SonarQube bootstrap failed; removing the newly created container: ${SONARQUBE_CONTAINER}" >&2
    docker rm -f "${SONARQUBE_CONTAINER}" >/dev/null
    echo "The incomplete SonarQube server was removed. Rerun this script to start with a clean server." >&2
}

# Track whether this script created the auth file so cleanup knows whether to
# remove it later.
AUTH_FILE_CREATED=false

# Temporary file that will hold the Jenkins node XML config.
NODE_CONFIG="$(mktemp)"

echo "Creating temporary Jenkins CLI auth file: ${AUTH_FILE}"

# This prompts you for the Jenkins API token. The token is not echoed on screen.
# The helper creates a file containing: username:apiToken
bash "${AUTH_SCRIPT}" "${AUTH_USERNAME}" "${AUTH_FILE}"
AUTH_FILE_CREATED=true

if [[ -z "${JOB_CONFIG}" ]]; then
    # If the user did not ask to keep the generated job XML, use a temp file.
    JOB_CONFIG="$(mktemp)"
    CLEAN_JOB_CONFIG=true
else
    # If JOB_CONFIG was supplied, preserve it for inspection/debugging.
    CLEAN_JOB_CONFIG=false
fi

cleanup() {
    # This function runs automatically when the script exits, even if a command
    # fails. It removes temporary files and the sensitive Jenkins CLI auth file.
    rm -f "${NODE_CONFIG}"
    if [[ "${CLEAN_JOB_CONFIG}" == "true" ]]; then
        rm -f "${JOB_CONFIG}"
    fi
    if [[ "${AUTH_FILE_CREATED}" == "true" ]]; then
        rm -f "${AUTH_FILE}"
        echo "Removed temporary Jenkins CLI auth file: ${AUTH_FILE}"
    fi
}
trap cleanup EXIT

if [[ "${START_SONARQUBE}" == "true" ]]; then
    # Start SonarQube locally with Docker if it is not already running.
    # This gives Jenkins a real SonarQube server to send scans to.
    if ! command -v docker >/dev/null 2>&1; then
        echo "Docker CLI is not available locally, so SonarQube cannot be started automatically." >&2
        echo "Install Docker or rerun with --start-sonarqube false if you already have SonarQube elsewhere." >&2
        exit 1
    fi

    if docker ps --format '{{.Names}}' | grep -Fxq "${SONARQUBE_CONTAINER}"; then
        echo "SonarQube container is already running: ${SONARQUBE_CONTAINER}"
    else
        if docker ps -a --format '{{.Names}}' | grep -Fxq "${SONARQUBE_CONTAINER}"; then
            echo "Starting existing SonarQube container: ${SONARQUBE_CONTAINER}"
            docker start "${SONARQUBE_CONTAINER}" >/dev/null
        else
            echo "Creating and starting SonarQube container: ${SONARQUBE_CONTAINER}"
            docker run -d \
                --name "${SONARQUBE_CONTAINER}" \
                -p "${SONARQUBE_PORT}:9000" \
                "${SONARQUBE_IMAGE}" >/dev/null
            SONARQUBE_CREATED=true
        fi
    fi

    # A root-page 200 can occur before SonarQube has registered all REST APIs.
    # Wait for the version API specifically before attempting password/token APIs.
    # SONARQUBE_URL is retained for Jenkins to reach SonarQube after bootstrap.
    wait_for_http "${SONARQUBE_BOOTSTRAP_URL}/api/server/version" "SonarQube REST API" 60

    # Only a newly created server needs first-run password setup and a Jenkins
    # analysis token. Existing servers are left untouched on reruns.
    if [[ "${SONARQUBE_CREATED}" == "true" ]]; then
        if ! initialize_fresh_sonarqube_password; then
            remove_failed_fresh_sonarqube
            exit 1
        fi
        if ! create_sonarqube_token; then
            remove_failed_fresh_sonarqube
            exit 1
        fi
        if ! register_sonarqube_in_jenkins; then
            remove_failed_fresh_sonarqube
            exit 1
        fi
    fi
fi

# Prepare XML-safe versions of values that will be inserted into node XML.
escaped_remote_fs="$(printf '%s' "${REMOTE_FS}" | xml_escape)"
escaped_labels="$(printf '%s' "${NODE_LABELS}" | xml_escape)"
escaped_node_name="$(printf '%s' "${NODE_NAME}" | xml_escape)"
groovy_node_name="$(printf '%s' "${NODE_NAME}" | groovy_string_escape)"

# Create Jenkins node XML.
# Jenkins CLI create-node/update-node expect this XML format.
# This defines an inbound/JNLP agent using WebSocket mode, which works well
# without opening a separate inbound TCP agent port.
cat > "${NODE_CONFIG}" <<XML
<?xml version='1.1' encoding='UTF-8'?>
<slave>
  <name>${escaped_node_name}</name>
  <description>Docker-based inbound Jenkins agent for DevOps Project pipeline.</description>
  <remoteFS>${escaped_remote_fs}</remoteFS>
  <numExecutors>${EXECUTORS}</numExecutors>
  <mode>NORMAL</mode>
  <retentionStrategy class="hudson.slaves.RetentionStrategy\$Always"/>
  <launcher class="hudson.slaves.JNLPLauncher">
    <workDirSettings>
      <disabled>false</disabled>
      <workDirPath>${escaped_remote_fs}</workDirPath>
      <internalDir>remoting</internalDir>
      <failIfWorkDirIsMissing>false</failIfWorkDirIsMissing>
    </workDirSettings>
    <webSocket>true</webSocket>
  </launcher>
  <label>${escaped_labels}</label>
  <nodeProperties/>
</slave>
XML

echo "Checking whether Jenkins node already exists: ${NODE_NAME}"

# If the node already exists, update it. Otherwise, create it.
# Redirecting output to /dev/null here is just for the existence check.
if java -jar "${CLI_JAR}" -s "${JENKINS_URL}" -http -auth "@${AUTH_FILE}" get-node "${NODE_NAME}" >/dev/null 2>&1; then
    echo "Node exists. Updating: ${NODE_NAME}"
    java -jar "${CLI_JAR}" -s "${JENKINS_URL}" -http -auth "@${AUTH_FILE}" update-node "${NODE_NAME}" < "${NODE_CONFIG}"
else
    echo "Node does not exist. Creating: ${NODE_NAME}"
    java -jar "${CLI_JAR}" -s "${JENKINS_URL}" -http -auth "@${AUTH_FILE}" create-node "${NODE_NAME}" < "${NODE_CONFIG}"
fi

echo "Retrieving inbound agent secret for node: ${NODE_NAME}"

# Jenkins inbound agents need a secret token to connect to the controller.
# Jenkins CLI does not have a simple built-in command for this, so we run a tiny
# Groovy script on the Jenkins controller to print the node's jnlpMac secret.
AGENT_SECRET="$({
    printf 'import jenkins.model.Jenkins\n'
    printf 'def n = Jenkins.instance.getNode("%s")\n' "${groovy_node_name}"
    printf 'println n?.computer?.jnlpMac\n'
} | java -jar "${CLI_JAR}" -s "${JENKINS_URL}" -http -auth "@${AUTH_FILE}" groovy = | tail -n 1)"

if [[ -z "${AGENT_SECRET}" || "${AGENT_SECRET}" == "null" ]]; then
    echo "Failed to retrieve agent secret for ${NODE_NAME}. Check Jenkins permissions and node configuration." >&2
    exit 1
fi

if [[ "${START_AGENT}" == "true" ]]; then
    # Starting the Docker container is optional, but enabled by default.
    # This turns the Jenkins node from "offline" into a connected/online agent.
    if ! command -v docker >/dev/null 2>&1; then
        echo "Docker CLI is not available locally, so the agent container cannot be started automatically." >&2
        echo "Install Docker or rerun with --start-agent false to only create/update Jenkins resources." >&2
        exit 1
    fi

    if ! docker image inspect "${AGENT_IMAGE}" >/dev/null 2>&1; then
        # The agent image must exist locally before we can run it.
        echo "Agent image is not present locally: ${AGENT_IMAGE}" >&2
        echo "Build it first with:" >&2
        echo "  docker build -f Jenkins/Dockerfile.agent -t ${AGENT_IMAGE} Jenkins" >&2
        exit 1
    fi

    if docker ps --format '{{.Names}}' | grep -Fxq "${NODE_NAME}"; then
        # Nothing to do if the correct container is already running.
        echo "Agent container is already running: ${NODE_NAME}"
    else
        if docker ps -a --format '{{.Names}}' | grep -Fxq "${NODE_NAME}"; then
            # A stopped container with the same name blocks docker run --name.
            # By default we remove it automatically.
            if [[ "${REPLACE_AGENT_CONTAINER}" == "true" ]]; then
                echo "Removing existing stopped agent container: ${NODE_NAME}"
                docker rm -f "${NODE_NAME}" >/dev/null
            else
                echo "A container named ${NODE_NAME} already exists. Rerun with --replace-agent true or remove it manually." >&2
                exit 1
            fi
        fi

        echo "Starting Docker agent container: ${NODE_NAME}"
        # Run the Jenkins inbound agent container in the background (-d).
        # /var/run/docker.sock is mounted so the agent can build and push Docker images.
        # --group-add gives the container user access to the host Docker socket group.
        docker run -d \
            --name "${NODE_NAME}" \
            -v /var/run/docker.sock:/var/run/docker.sock \
            --group-add "$(stat -c '%g' /var/run/docker.sock)" \
            "${AGENT_IMAGE}" \
            -url "${JENKINS_URL}" \
            -webSocket \
            -secret "${AGENT_SECRET}" \
            -name "${NODE_NAME}"
    fi
fi

echo "Validating Jenkinsfile with Jenkins declarative linter..."

# Ask Jenkins itself to validate the Jenkinsfile syntax before creating/updating
# the job. This catches Jenkins-specific Pipeline syntax issues.
java -jar "${CLI_JAR}" \
    -s "${JENKINS_URL}" \
    -http \
    -auth "@${AUTH_FILE}" \
    declarative-linter < "${JENKINSFILE}"

echo "Generating Pipeline job config XML for job: ${JOB_NAME}"

# Jenkins jobs are configured with XML. For a Pipeline job, we create a
# flow-definition and embed the Jenkinsfile content inside the <script> tag.
{
    cat <<'XML_HEAD'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <actions/>
  <description>Pipeline job created by scripts/create_jenkins_pipeline_job.sh</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">
    <script>
XML_HEAD
    # Escape Jenkinsfile characters that would otherwise break XML.
    sed \
        -e 's/&/\&amp;/g' \
        -e 's/</\&lt;/g' \
        -e 's/>/\&gt;/g' "${JENKINSFILE}"
    cat <<'XML_TAIL'
    </script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
XML_TAIL
} > "${JOB_CONFIG}"

echo "Checking whether Jenkins job already exists: ${JOB_NAME}"

# Same pattern as the node: update if it already exists, otherwise create it.
if java -jar "${CLI_JAR}" \
    -s "${JENKINS_URL}" \
    -http \
    -auth "@${AUTH_FILE}" \
    get-job "${JOB_NAME}" >/dev/null 2>&1; then
    echo "Job exists. Updating: ${JOB_NAME}"
    java -jar "${CLI_JAR}" \
        -s "${JENKINS_URL}" \
        -http \
        -auth "@${AUTH_FILE}" \
        update-job "${JOB_NAME}" < "${JOB_CONFIG}"
else
    echo "Job does not exist. Creating: ${JOB_NAME}"
    java -jar "${CLI_JAR}" \
        -s "${JENKINS_URL}" \
        -http \
        -auth "@${AUTH_FILE}" \
        create-job "${JOB_NAME}" < "${JOB_CONFIG}"
fi

cat <<RUN_CMD

# Final instructions are printed so you can see what was created and how to
# start the agent manually if automatic startup was disabled or failed.

Done. Jenkins job is available at: ${JENKINS_URL%/}/job/${JOB_NAME}/

SonarQube startup: ${START_SONARQUBE}
SonarQube URL for Jenkins configuration: ${SONARQUBE_URL}
SonarQube Jenkins server name expected by Jenkinsfile: SonarQube

If this script created a fresh SonarQube server, it prompted you for the new admin password
and printed one Jenkins analysis token. Copy that token now; SonarQube will not show it again.
On later runs the existing SonarQube server and its tokens are left untouched.
Then configure Jenkins → Manage Jenkins → System → SonarQube servers with:
  Name: SonarQube
  Server URL: ${SONARQUBE_URL}

Also configure this SonarQube webhook for Quality Gate callbacks:
  ${JENKINS_URL%/}/sonarqube-webhook/

Required Jenkins agent node is ready: ${NODE_NAME}
Labels: ${NODE_LABELS}

Agent container startup: ${START_AGENT}

Manual agent start command, if needed:

docker run --rm \\
  --name ${NODE_NAME} \\
  -v /var/run/docker.sock:/var/run/docker.sock \\
  --group-add "\$(stat -c '%g' /var/run/docker.sock)" \\
  ${AGENT_IMAGE} \\
  -url '${JENKINS_URL}' \\
  -webSocket \\
  -secret '${AGENT_SECRET}' \\
  -name '${NODE_NAME}'

If startup was enabled, the agent should be coming online now. Build the Jenkins job after the node is online.
RUN_CMD