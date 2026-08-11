# Ansible deployment layer

This directory contains the control-node automation that orchestrates guarded
Terraform lifecycle stages and prepares EKS application configuration.

Main project documentation: [../README.md](../README.md)

## Assumptions

- control node is Linux-based (commands/examples are Linux-first)
- `ansible` is installed locally and `ANSIBLE_CONFIG=ansible.cfg` is used when running playbooks
- AWS credentials for Terraform/Ansible orchestration are already configured on the control node
- `terraform`, AWS CLI, and `kubectl` are available for the stages that use them
- AWS and Kubernetes mutations are enabled only through the documented opt-in flags

## What this Ansible layer does

- validates and orchestrates Terraform state/infrastructure through guarded,
  opt-in lifecycle stages (`playbooks/configure_terraform_state.yml`)
- creates encrypted local environment inputs and, only when enabled, regenerates
  effective Terraform inputs from the committed example
- optionally writes reviewed, non-password Terraform runtime outputs to ignored
  mode-0600 `recovery/application-runtime.yml`, then independently synchronizes
  the Terraform-owned RDS password into namespace-scoped `worker-db-secret`
- seeds private Jenkins CI/CD jobs and can queue CI through a short-lived
  in-cluster Job; CI owns image publication and initial `index.html`, then hands
  off to standalone FULL CD when `DEPLOY_TO_EKS=true`

## Main playbooks

- `playbooks/site.yml` — authoritative guarded lifecycle entry point
- `playbooks/setup_local_environment.yml` — one-time interactive email/CIDR setup,
  deterministic DB username derivation, and local Ansible Vault creation
- `playbooks/prepare_terraform_inputs.yml` — gated `terraform.tfvars` regeneration
  and read-only AWS caller-identity preflight
- `playbooks/configure_terraform_state.yml` — remote-state bootstrap and guarded
  Terraform lifecycle tasks
- `playbooks/configure_eks_platform.yml` — guarded Terraform-output kubeconfig,
  pinned Jenkins Helm release, and namespace-scoped deployer RBAC lifecycle
- `playbooks/prepare_application_runtime.yml` — independently gated non-secret
  Terraform-output handoff preparation
- `playbooks/prepare_application_secret.yml` — independently gated Secrets Manager
  to Kubernetes Secret synchronization from the prepared handoff
- `playbooks/seed_jenkins_jobs.yml` — Ansible-native in-cluster Jenkins HTTP API
  seeding for separate inline CI and CD jobs from the non-secret runtime handoff
- `playbooks/trigger_jenkins_ci.yml` — guarded in-cluster queue handoff to CI with
  `DEPLOY_TO_EKS=true`; Jenkins owns all subsequent CI and standalone CD work
- `playbooks/destroy.yml` — separate dependency-ordered full-stack teardown; it is
  intentionally not imported by `site.yml`

## Useful run commands

```bash
cd Ansible-modules-01

# One-time local setup: prompts for email, detects and confirms/overrides the
# administrator IPv4 /32, and writes only ignored mode-0600 encrypted files.
ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbooks/setup_local_environment.yml

# Regenerate ignored terraform.tfvars from the committed example and inject only
# the encrypted local values. This also performs a read-only AWS STS preflight.
PREPARE_TERRAFORM_INPUTS=true \
  ANSIBLE_VAULT_PASSWORD_FILE=.vault-password \
  ANSIBLE_CONFIG=ansible.cfg \
  ansible-playbook playbooks/prepare_terraform_inputs.yml

# Safe local validation; all mutation stages default off
ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbooks/site.yml

# After reviewing Terraform state/outputs and the target AWS identity, prepare an
# isolated mode-0600 kubeconfig. Jenkins Helm/RBAC mutations require the two
# additional flags and the exact confirmation shown below.
PREPARE_EKS_PREREQUISITES=true \
  DEPLOY_JENKINS_PLATFORM=true \
  APPLY_JENKINS_RBAC=true \
  EKS_PLATFORM_MUTATION_CONFIRMATION=EKS_PLATFORM_MUTATION_APPROVED \
  ANSIBLE_CONFIG=ansible.cfg \
  ansible-playbook playbooks/configure_eks_platform.yml

# Launch a short-lived hardened Kubernetes Job that reads the official chart's
# admin Secret inside the jenkins namespace and seeds CD first, then CI, through
# the private ClusterIP Service. No credential is passed from the control node.
SEED_JENKINS_JOBS=true \
  JENKINS_JOB_MUTATION_CONFIRMATION=JENKINS_JOB_MUTATION_APPROVED \
  ANSIBLE_CONFIG=ansible.cfg \
  ansible-playbook playbooks/seed_jenkins_jobs.yml

# Optional interactive UI fallback; Jenkins has no public load balancer/Ingress.
kubectl --kubeconfig recovery/target-kubeconfig \
  -n jenkins port-forward svc/jenkins 18080:8080

# Safe destroy validation; defaults to local assertions/debug only
ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbooks/destroy.yml

# After reviewing Terraform outputs, write the ignored non-password handoff.
PREPARE_APPLICATION_RUNTIME=true \
  ANSIBLE_CONFIG=ansible.cfg \
  ansible-playbook playbooks/prepare_application_runtime.yml

# After the namespace exists, synchronize the database Secret from the prepared
# handoff, seed Jenkins jobs, then queue CI. CI seeds missing index.html and its
# DEPLOY_TO_EKS=true run waits for standalone FULL CD.
SYNC_APPLICATION_SECRET=true \
  APPLICATION_SECRET_MUTATION_CONFIRMATION=APPLICATION_SECRET_MUTATION_APPROVED \
  ANSIBLE_CONFIG=ansible.cfg \
  ansible-playbook playbooks/prepare_application_secret.yml
TRIGGER_JENKINS_CI=true \
  JENKINS_CI_TRIGGER_CONFIRMATION=JENKINS_CI_TRIGGER_APPROVED \
  ANSIBLE_CONFIG=ansible.cfg \
  ansible-playbook playbooks/trigger_jenkins_ci.yml
```

## Full-stack destroy

`playbooks/destroy.yml` is the routine destroy interface after the Terraform-owned
stack has been created and verified. It refuses execution unless Terraform state
contains the expected EKS, RDS, and application S3 resources, the active Kubernetes
context and API endpoint match Terraform outputs, and the exact confirmation is:

```text
DESTROY <terraform-eks-cluster-name> <terraform-application-bucket-name>
```

When explicitly enabled, the playbook optionally downloads `index.html` and
`instances.json` into ignored `recovery/<UTC timestamp>/`, removes application and
Jenkins Helm releases, deletes the disposable Jenkins PVC and namespaces, deletes
those two application objects, and runs one Terraform main-stack destroy. The
separate Terraform remote-state bucket remains retained.

```bash
DESTROY_EXECUTE=true \
  RETAIN_APPLICATION_DATA=true \
  EXPECTED_KUBE_CONTEXT='<reviewed-context>' \
  DESTROY_CONFIRMATION='DESTROY <cluster> <application-bucket>' \
  ANSIBLE_CONFIG=ansible.cfg \
  ansible-playbook playbooks/destroy.yml
```

Do not run the enabled path during the current empty-state Phase 1 boundary. The
workflow has only local/static validation and has not been cloud-tested. Residual
billable-resource inspection is a separate optional read-only operational check,
not a step or ownership responsibility of this destroy playbook.

The generated `.vault-password` and `vault/local-environment.yml` files are
ignored and mode `0600`. Post-setup runs that decrypt the local file set
`ANSIBLE_VAULT_PASSWORD_FILE=.vault-password`, which supports unattended Ansible
without breaking clean-clone syntax/default validation. The encrypted file contains
only the administrator email, administrator `/32`, and deterministic DB username.
They must never contain AWS credentials or the generated database password.
Manual edits to generated `terraform/terraform.tfvars` are unsupported; update
the committed example for non-secret settings and rerun the preparation stage.


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

AWS Secrets Manager remains the upstream source of truth, but the Kubernetes copy
must be resynchronized and worker Pods rolled after password rotation. Restrict
RBAC access to the Secret and use EKS encryption at rest for Kubernetes Secrets.

## Notes

- This is a control-node workflow; do not run the lifecycle on cluster nodes.
- `PREPARE_APPLICATION_RUNTIME=true` reads Terraform outputs and writes only the
  ignored non-password handoff. `SYNC_APPLICATION_SECRET=true` later performs the
  AWS secret read and Kubernetes mutation from that handoff; both default off.
- `PREPARE_TERRAFORM_INPUTS=true` rewrites only the ignored effective tfvars and
  performs a read-only AWS identity check; it does not apply Terraform.
- `configure_eks_platform.yml` never creates IAM roles, EKS access entries, or Pod
  Identity associations; those remain Terraform-owned. Its mutating scope is the
  pinned Jenkins Helm release and reviewed Kubernetes RBAC only.
- `seed_jenkins_jobs.yml` replaces the transitional job-creation shell workflow.
  Its short-lived non-root Job reads the chart admin Secret through `secretKeyRef`,
  calls only the private Jenkins Service, and never places the database password
  in Jenkins parameters, job XML, ConfigMaps, logs, or control-node environment.
- `trigger_jenkins_ci.yml` only queues the seeded CI job with
  `DEPLOY_TO_EKS=true`; it does not duplicate Jenkins build, S3, Helm, or CD logic.
  A successful trigger Job proves queue handoff, while Jenkins build results are
  the authoritative evidence for CI and the synchronous standalone CD run.
- Never add secret-value debug tasks or remove `no_log: true` from secret handling.
- Archived direct Terraform/eksctl/Helm helpers live under `../scripts/legacy/`
  for provenance only. They are not supported lifecycle entry points.