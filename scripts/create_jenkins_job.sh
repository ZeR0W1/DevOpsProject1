#!/usr/bin/env bash
set -euo pipefail

# Generic creator/updater for an inline Jenkins Declarative Pipeline job.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JENKINS_URL="${JENKINS_URL:-}"
JOB_NAME="${JOB_NAME:-}"
JENKINSFILE="${JENKINSFILE:-}"
JOB_DESCRIPTION="${JOB_DESCRIPTION:-Jenkins Pipeline managed by scripts/create_jenkins_job.sh}"
CLI_JAR="${CLI_JAR:-$PROJECT_ROOT/Jenkins/jenkins-cli.jar}"
AUTH_FILE="${AUTH_FILE:-${HOME}/.jenkins-cli-auth}"
AUTH_USERNAME="${AUTH_USERNAME:-admin}"
AUTH_SCRIPT="${AUTH_SCRIPT:-$PROJECT_ROOT/scripts/create_jenkins_cli_auth.sh}"
STRING_PARAM_NAMES=()
STRING_PARAM_DEFAULTS=()
STRING_PARAM_DESCRIPTIONS=()
BOOLEAN_PARAM_NAMES=()
BOOLEAN_PARAM_DEFAULTS=()
BOOLEAN_PARAM_DESCRIPTIONS=()

usage() {
  cat <<USAGE
Usage: $(basename "$0") --url URL --job-name NAME --jenkinsfile PATH [options]

Validate a Declarative Jenkinsfile, then create or update an inline Pipeline job.

Required:
  --url URL          Jenkins controller URL, or set JENKINS_URL.
  --job-name NAME    Jenkins job name, or set JOB_NAME.
  --jenkinsfile PATH Jenkinsfile path, or set JENKINSFILE.

Options:
  --description TEXT Job description.
  --string-param NAME DEFAULT DESCRIPTION
                     Pre-seed a string build parameter. Repeatable.
  --boolean-param NAME DEFAULT DESCRIPTION
                     Pre-seed a boolean parameter; DEFAULT is true or false. Repeatable.
  --cli-jar PATH     Jenkins CLI jar. Default: ${CLI_JAR}
  --auth-user USER   User whose API token is prompted for. Default: ${AUTH_USERNAME}
  -h, --help         Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) JENKINS_URL="${2:?Missing URL}"; shift 2 ;;
    --job-name) JOB_NAME="${2:?Missing job name}"; shift 2 ;;
    --jenkinsfile) JENKINSFILE="${2:?Missing Jenkinsfile path}"; shift 2 ;;
    --description) JOB_DESCRIPTION="${2:?Missing description}"; shift 2 ;;
    --string-param)
      STRING_PARAM_NAMES+=("${2:?Missing parameter name}")
      STRING_PARAM_DEFAULTS+=("${3-}")
      STRING_PARAM_DESCRIPTIONS+=("${4:?Missing parameter description}")
      shift 4
      ;;
    --boolean-param)
      [[ "${3-}" == true || "${3-}" == false ]] || {
        echo "Boolean parameter ${2:-<unknown>} must default to true or false." >&2
        exit 2
      }
      BOOLEAN_PARAM_NAMES+=("${2:?Missing parameter name}")
      BOOLEAN_PARAM_DEFAULTS+=("$3")
      BOOLEAN_PARAM_DESCRIPTIONS+=("${4:?Missing parameter description}")
      shift 4
      ;;
    --cli-jar) CLI_JAR="${2:?Missing CLI jar path}"; shift 2 ;;
    --auth-user) AUTH_USERNAME="${2:?Missing username}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$JENKINS_URL" ]] || { echo 'Missing --url URL (or JENKINS_URL).' >&2; exit 2; }
[[ -n "$JOB_NAME" ]] || { echo 'Missing --job-name NAME (or JOB_NAME).' >&2; exit 2; }
[[ -n "$JENKINSFILE" ]] || { echo 'Missing --jenkinsfile PATH (or JENKINSFILE).' >&2; exit 2; }

for path in "$JENKINSFILE" "$CLI_JAR" "$AUTH_SCRIPT"; do
  [[ -f "$path" ]] || { echo "Required file not found: $path" >&2; exit 1; }
done

AUTH_FILE_CREATED=false
JOB_CONFIG="$(mktemp)"
cleanup() {
  rm -f "$JOB_CONFIG"
  if [[ "$AUTH_FILE_CREATED" == true ]]; then rm -f "$AUTH_FILE"; fi
}
trap cleanup EXIT

bash "$AUTH_SCRIPT" "$AUTH_USERNAME" "$AUTH_FILE"
AUTH_FILE_CREATED=true

echo "Validating Jenkinsfile: $JENKINSFILE"
java -jar "$CLI_JAR" -s "$JENKINS_URL" -http -auth "@${AUTH_FILE}" declarative-linter < "$JENKINSFILE"

xml_escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&apos;/g"
}

{
  cat <<'XML_HEAD'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <actions/>
  <description>
XML_HEAD
  printf '%s' "$JOB_DESCRIPTION" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
  cat <<'XML_MIDDLE'
</description>
  <keepDependencies>false</keepDependencies>
XML_MIDDLE
  if (( ${#STRING_PARAM_NAMES[@]} + ${#BOOLEAN_PARAM_NAMES[@]} > 0 )); then
    cat <<'XML_PARAMETERS_HEAD'
  <properties>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
XML_PARAMETERS_HEAD
    for index in "${!STRING_PARAM_NAMES[@]}"; do
      printf '%s' '        <hudson.model.StringParameterDefinition><name>'
      xml_escape "${STRING_PARAM_NAMES[$index]}"
      printf '%s' '</name><description>'
      xml_escape "${STRING_PARAM_DESCRIPTIONS[$index]}"
      printf '%s' '</description><defaultValue>'
      xml_escape "${STRING_PARAM_DEFAULTS[$index]}"
      printf '%s\n' '</defaultValue><trim>true</trim></hudson.model.StringParameterDefinition>'
    done
    for index in "${!BOOLEAN_PARAM_NAMES[@]}"; do
      printf '%s' '        <hudson.model.BooleanParameterDefinition><name>'
      xml_escape "${BOOLEAN_PARAM_NAMES[$index]}"
      printf '%s' '</name><description>'
      xml_escape "${BOOLEAN_PARAM_DESCRIPTIONS[$index]}"
      printf '%s\n' "</description><defaultValue>${BOOLEAN_PARAM_DEFAULTS[$index]}</defaultValue></hudson.model.BooleanParameterDefinition>"
    done
    cat <<'XML_PARAMETERS_TAIL'
      </parameterDefinitions>
    </hudson.model.ParametersDefinitionProperty>
  </properties>
XML_PARAMETERS_TAIL
  else
    printf '%s\n' '  <properties/>'
  fi
  cat <<'XML_DEFINITION'
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">
    <script>
XML_DEFINITION
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' "$JENKINSFILE"
  cat <<'XML_TAIL'
    </script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
XML_TAIL
} > "$JOB_CONFIG"

if java -jar "$CLI_JAR" -s "$JENKINS_URL" -http -auth "@${AUTH_FILE}" get-job "$JOB_NAME" >/dev/null 2>&1; then
  java -jar "$CLI_JAR" -s "$JENKINS_URL" -http -auth "@${AUTH_FILE}" update-job "$JOB_NAME" < "$JOB_CONFIG"
  echo "Updated Jenkins Pipeline job: $JOB_NAME"
else
  java -jar "$CLI_JAR" -s "$JENKINS_URL" -http -auth "@${AUTH_FILE}" create-job "$JOB_NAME" < "$JOB_CONFIG"
  echo "Created Jenkins Pipeline job: $JOB_NAME"
fi