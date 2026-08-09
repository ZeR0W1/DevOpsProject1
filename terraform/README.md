# Terraform infrastructure layer

This directory defines the target AWS infrastructure for the EKS application.
Ansible is the lifecycle orchestrator; Terraform configuration and state remain the
authoritative owners of AWS resources. See [../README.md](../README.md) for the
project overview and [../.clinerules/90-current-project-status.md](../.clinerules/90-current-project-status.md)
for the current safety boundary.

## Main-stack scope

- VPC, public/private/database subnets, routing, one NAT gateway, and security groups
- EKS control plane, private managed node group, add-ons, EBS CSI IRSA, and worker
  Pod Identity association
- private RDS PostgreSQL and its EKS-node-to-database security-group path
- private application-content/catalog S3 bucket
- SNS topic/subscription, Secrets Manager resources, IAM policies, and monitoring

The application bucket stores the versioned `index.html` bootstrap object and the
worker's synchronized `instances.json` backup. It is not the Terraform state bucket.

## Module map

- `modules/networking` — VPC, subnets, routes, NAT, and security groups
- `modules/eks` — EKS cluster, managed nodes, add-ons, and EBS CSI identity
- `modules/iam` — narrowly scoped worker S3/SNS role used through Pod Identity
- `modules/rds_postgresql` — PostgreSQL database resources
- `modules/s3_bucket` — application content/catalog storage
- `modules/sns_topic` — notifications
- `modules/services` — operational monitoring

The legacy `modules/ec2` directory is not composed by the root module. Its final
cleanup is deferred until the repository-wide redundancy inventory is complete.

## Inputs, outputs, and secrets

- Root inputs are declared in `variables.tf`.
- Non-secret examples are in `terraform.tfvars.example`.
- That example is authoritative. The guarded Ansible input stage overwrites the
  ignored effective `terraform.tfvars` and replaces only `admin_email`,
  `admin_cidr`, and the deterministic `db_username` from encrypted local inputs.
- Real `terraform.tfvars`, state, plans, and generated remote-state settings are
  ignored and must not be printed or committed.
- `secrets.tf` generates the database password and stores it in Secrets Manager;
  the root `db_password_secret_name` remains active.
- RDS is intentionally disposable and reproducible: the module fixes encrypted
  `gp3` storage, private access, zero backup retention, no final snapshot, and no
  deletion protection. Its generated password secret uses immediate deletion to
  follow the same reviewed stack boundary.
- Outputs in `outputs.tf` expose non-secret integration identifiers and sensitive
  values only where explicitly marked.

## Automated remote state

`state-bootstrap/` is a separate Terraform root that uses local bootstrap state to
create and harden a reusable Terraform-state S3 bucket. It enables versioning,
AES-256 encryption, bucket-owner enforcement, full public-access blocking,
TLS-only access, and `prevent_destroy`.

The main stack declares a partial S3 backend in `providers.tf` with native S3 lock
files (`use_lockfile = true`). Ansible reads the state-bootstrap outputs and writes
ignored `remote-state.hcl` containing the bucket, state key, and region. Native
locking prevents concurrent Terraform runs from changing the same state; no
DynamoDB lock table is required.

The state bucket and application bucket are intentionally separate:

- the state bucket must exist before the main stack can initialize;
- main-stack teardown must not remove its own ownership record;
- application workload identities must never access Terraform state; and
- state retention/versioning has a different lifecycle from application objects.

The state bootstrap is automated through
`../Ansible-modules-01/playbooks/configure_terraform_state.yml`; no manual bucket
creation is required in the intended final workflow. The state bucket is retained
by default, and deleting it is a separate explicit retained-data decision.

## Phase 1 ownership boundary

Phase 1 is local/static only. The current local main-stack state last listed zero
resources. The similarly named live `devops-app-eks` environment was created by
temporary shell/`eksctl`/CloudFormation flows and is not Terraform-owned.

Do not run main-stack `apply`, `import`, backend initialization/migration, or
destroy until the user approves a resource-by-resource import-versus-recreation
plan and state transition. Never apply an empty state to an existing environment
as implicit adoption.

Also preserve these external resources:

- legacy S3 bucket `quick-demo-058264247987-us-east-1-an`; do not use it for the
  new application bucket or Terraform state; and
- termination-protected CloudFormation stack `eksctl-learn-eks-cluster`; do not
  import, update, unprotect, or delete it during Phase 1.

## Safe local validation

The guarded Ansible playbook defaults all mutation flags to false and performs
provider initialization with backend configuration disabled, formatting checks,
and validation:

```bash
ANSIBLE_CONFIG=Ansible-modules-01/ansible.cfg \
  ansible-playbook Ansible-modules-01/playbooks/configure_terraform_state.yml
```

Equivalent focused checks are:

```bash
terraform -chdir=terraform/state-bootstrap init -backend=false -input=false
terraform -chdir=terraform/state-bootstrap validate -no-color
terraform -chdir=terraform fmt -check -recursive -diff
terraform -chdir=terraform init -backend=false -input=false
terraform -chdir=terraform validate -no-color
terraform -chdir=terraform state list
```

Provider download during `init -backend=false` does not configure remote state or
create AWS resources. A plan may perform AWS reads and is not part of the routine
local validation above.

## Direct Terraform recovery runbook

Ansible is the normal supported create/destroy interface. Direct Terraform use is
reserved for diagnostics and exceptional recovery; it must not become a parallel
routine lifecycle path.

### Tier 1 — local diagnostics (safe Phase 1 operations)

- Run `terraform fmt -check -recursive -diff` and `terraform validate` after
  provider-only `init -backend=false`.
- Inspect committed configuration and allow-listed non-secret inputs only.
- Inspect the preserved local state file read-only when needed; never print state
  contents or sensitive outputs.
- Do not run `plan` merely as a syntax check: it can perform provider/AWS reads.

### Tier 2 — backend/state connectivity recovery (review required)

- First confirm the intended AWS account/region, state bucket, state key, current
  ownership boundary, and whether local or remote state is authoritative.
- Preserve timestamped state backups outside Git before any backend operation.
- Use `init -reconfigure` only for an already reviewed fresh backend connection;
  use `init -migrate-state` only for a separately approved migration with both
  source and destination backups.
- If locking fails, identify the active operator/process and verify no run remains.
  `force-unlock` is a state mutation and requires exact explicit approval; never
  remove a lock merely because it is inconvenient.

### Tier 3 — emergency resource/state mutation (explicit approval only)

- `apply`, `destroy`, `import`, `state mv/rm`, replacement flags, and manual state
  recovery are emergency-only actions requiring a reviewed resource-specific plan,
  cost/dependency impact, rollback limitations, and exact user authorization.
- Never apply empty/stale state to matching live resources as implicit adoption.
  This project selected deliberate parallel recreation with a distinct Terraform
  EKS cluster name; the current eksctl environment remains externally owned.
- After any approved direct recovery, reconcile state/configuration and rerun the
  authoritative Ansible workflow so subsequent lifecycle ordering remains coherent.
- Never edit Terraform state files manually or expose state, plans, credentials,
  database values, tokens, or other sensitive outputs in logs or documentation.

## Future approved lifecycle

After state ownership, migration/recreation, effective inputs, costs, and AWS reads
are reviewed, the same Ansible playbook can explicitly gate these stages:

1. apply the state bootstrap;
2. generate `remote-state.hcl`;
3. initialize a fresh main state or perform the separately approved migration;
4. apply Terraform-owned AWS infrastructure; and
5. continue the broader Ansible EKS/Jenkins/application create workflow.

The Phase 1 false defaults should be revisited after migration so normal
idempotent create stages are convenient, while one-time migration and all
destructive actions remain explicitly confirmed. Teardown belongs in a separate,
dependency-ordered, cost-aware workflow and retains remote state by default.
