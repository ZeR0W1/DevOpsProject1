# Ansible deployment layer

This directory contains the control-node automation that orchestrates guarded
Terraform lifecycle stages and prepares EKS application configuration.

Main project documentation: [../README.md](../README.md)

## Runtime convention

Run `bash ../setup.sh` first, then invoke every playbook from this
directory with the project-local environment and the single authoritative config:

```bash
source ../.venv/bin/activate
export ANSIBLE_CONFIG="$PWD/ansible.cfg"
```

The root [README](../README.md) documents workstation and AWS prerequisites.

The root `.venv` is only for lifecycle-controller tools. Install application
runtime and test dependencies in service-local virtual environments, such as
`app/src/worker/.venv`, or in CI. The controller and worker intentionally use
independently pinned AWS SDK versions and must not share one Python environment.

## What this Ansible layer does

- validates and orchestrates Terraform state/infrastructure through guarded,
  opt-in lifecycle stages (`playbooks/create/configure_terraform_state.yml`)
- creates encrypted local environment inputs and, only when enabled, regenerates
  effective Terraform inputs from the committed example
- optionally writes reviewed, non-password Terraform runtime outputs to ignored
  mode-0600 `recovery/application-runtime.yml`, then independently synchronizes
  the Terraform-owned RDS password into namespace-scoped `worker-db-secret`
- seeds private Jenkins CI/CD jobs and can queue CI through a short-lived
  in-cluster Job; CI owns image publication and initial `index.html`, then hands
  off to standalone FULL CD when `DEPLOY_TO_EKS=true`

## Main playbooks

- `playbooks/create.yml` — supported interactive complete create lifecycle
- `playbooks/create/lifecycle.yml` — ordered internal create lifecycle orchestrator
- `playbooks/create/setup/setup_local_environment.yml` — one-time interactive email/CIDR setup,
  deterministic DB username derivation, and local Ansible Vault creation
- `playbooks/create/prepare_terraform_inputs.yml` — gated `terraform.tfvars` regeneration
  and read-only AWS caller-identity preflight
- `playbooks/create/configure_terraform_state.yml` — remote-state bootstrap and guarded
  Terraform lifecycle tasks
- `playbooks/create/configure_eks_platform.yml` — guarded Terraform-output kubeconfig,
  pinned Jenkins Helm release, and namespace-scoped deployer RBAC lifecycle
- `playbooks/create/prepare_application_runtime.yml` — independently gated non-secret
  Terraform-output handoff preparation
- `playbooks/create/prepare_application_secret.yml` — independently gated Secrets Manager
  to Kubernetes Secret synchronization from the prepared handoff
- `playbooks/create/seed_jenkins_jobs.yml` — Ansible-native in-cluster Jenkins HTTP API
  seeding for separate inline CI and CD jobs from the non-secret runtime handoff
- `playbooks/create/trigger_jenkins_ci.yml` — guarded in-cluster queue handoff to CI with
  `DEPLOY_TO_EKS=true`; Jenkins owns all subsequent CI and standalone CD work
- `playbooks/destroy.yml` — supported guarded destroy and Terraform-resume wrapper
- `playbooks/destroy/lifecycle.yml` — ordered internal normal-destroy orchestrator

## Create lifecycle

```bash
ansible-playbook playbooks/create.yml
```

Choose `DEPLOY_DEFAULT` to deploy the promoted public immutable images without
registry credentials, or `BUILD_AND_DEPLOY` to validate Docker Hub credentials,
run CI, publish all three images under one immutable tag, and hand off to standalone
FULL CD. The playbook displays the AWS account, region, billable resources, and
retained-state decision before requiring the exact `CREATE` confirmation.

The wrapper enables lower-level stages only for the confirmed run. Invoking a
component playbook directly leaves mutation flags disabled by default.

## Generated local files

- `.vault-password` and `vault/local-environment.yml` are ignored mode-`0600`
  files created by setup. The encrypted environment file contains the administrator
  email/CIDR and deterministic database username; build mode may add Docker Hub
  credentials.
- `../terraform/terraform.tfvars` is regenerated from the committed example; do
  not edit or commit it.
- `../terraform/remote-state.hcl` is generated from state-bootstrap outputs.
- `recovery/target-kubeconfig` isolates all Kubernetes operations to the
  Terraform-created cluster.
- `recovery/application-runtime.yml` contains only non-password deployment
  metadata. The database password is never written to it.

## Full-stack destroy

`playbooks/destroy.yml` is the routine destroy interface after the Terraform-owned
stack has been created and verified. It refuses execution unless Terraform state
contains the expected EKS, RDS, and application S3 resources, the active Kubernetes
context and API endpoint match Terraform outputs. It displays the Terraform-owned
cluster, application bucket, resource count, and retained remote-state boundary,
then requires the exact confirmation:

```text
DESTROY
```

If Terraform reports a narrowly classified transient provider, network, timeout,
or throttling failure, Ansible waits briefly and retries the same state-driven
destroy exactly once. A final failure preserves partial state and prints a
human-readable Terraform error summary with credential-like patterns redacted,
plus only the remaining Terraform state addresses. It never performs generic
out-of-state cleanup. Correct the reported root cause or verify the exact external
blocker, then rerun the same wrapper with
`DESTROY_EXECUTE=true DESTROY_RESUME=true`. Resume mode displays and confirms only
the remaining Terraform-owned count and reuses the same retry/diagnostic policy;
it does not repeat Kubernetes, GitHub webhook, application-data, or certificate
stages.

When explicitly enabled, the playbook optionally downloads `index.html` and
`instances.json` into ignored `recovery/<UTC timestamp>/`, removes the exact
project GitHub webhook, purges all user-installed content from the verified
dedicated EKS cluster, deletes those two application objects, and runs one full
Terraform main-stack destroy. Any released Ansible-owned self-signed certificate
is removed only after Terraform succeeds. The separate Terraform remote-state
bucket remains retained.

```bash
DESTROY_EXECUTE=true \
  RETAIN_APPLICATION_DATA=true \
  ansible-playbook playbooks/destroy.yml
```

## Database secret responsibilities

- **Terraform** creates the RDS password and its AWS Secrets Manager secret.
- **Ansible** reads that value only during an explicitly enabled deployment stage
  and creates or updates `devops-app/worker-db-secret` with `no_log: true`.
- The ignored mode-0600 runtime handoff contains only deployment metadata such as
  RDS endpoint/name/user/port, AWS region, S3 bucket, SNS topic ARN, and Secret
  names; it never contains the database password value.
- **Helm/Kubernetes** injects the `password` key into the worker as
  `POSTGRES_PASSWORD`; the password is never committed to Git or written to a
  generated workspace file.
- **Worker Pod Identity** remains scoped to runtime S3 and SNS responsibilities;
  the worker does not read Secrets Manager directly.

AWS Secrets Manager remains the upstream source of truth. After password rotation,
rerun the synchronization stage through the complete lifecycle and roll the worker
Pods. Never add secret-value debug tasks or remove `no_log: true` from secret
handling.

## Private Jenkins access

Jenkins has no public LoadBalancer or Ingress. For temporary operator access:

```bash
kubectl --kubeconfig recovery/target-kubeconfig \
  -n jenkins port-forward svc/jenkins 18080:8080
```