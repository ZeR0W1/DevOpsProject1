# Terraform infrastructure layer

This directory defines the target AWS infrastructure for the EKS application.
Ansible is the lifecycle orchestrator; Terraform configuration and state remain the
authoritative owners of AWS resources. See [../README.md](../README.md) for the
project overview and [../Ansible-modules-01/README.md](../Ansible-modules-01/README.md)
for lifecycle commands.

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
`../Ansible-modules-01/playbooks/create/configure_terraform_state.yml`; no manual bucket
creation is required in the intended final workflow. The state bucket is retained
by default, and deleting it is a separate explicit retained-data decision.

## Ownership boundary

The retained state-bootstrap root owns only the hardened remote-state bucket. The
main root owns only resources listed in its remote state. Ansible invokes both
roots in dependency order; matching names never authorize import or adoption of
resources outside the applicable state.

## Safe local validation

The guarded Ansible playbook defaults all mutation flags to false and performs
provider initialization with backend configuration disabled, formatting checks,
and validation:

```bash
cd Ansible-modules-01
source ../.venv/bin/activate
export ANSIBLE_CONFIG="$PWD/ansible.cfg"
ansible-playbook playbooks/create/configure_terraform_state.yml
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

## Direct Terraform use

Ansible is the normal supported create/destroy interface. Direct Terraform use is
reserved for diagnostics and exceptional recovery; it must not become a parallel
routine lifecycle path.

- Use backend-disabled initialization plus `fmt` and `validate` for local checks.
- Before backend recovery, confirm account, region, bucket, key, and authoritative
  state; preserve backups before reconfiguration or migration.
- Treat `apply`, `destroy`, `import`, state movement/removal, replacement flags,
  migration, and force-unlock as reviewed state or infrastructure mutations.
- Never apply empty or stale state to similarly named resources as implicit
  adoption, edit state manually, or expose state, plans, credentials, or secrets.
- After exceptional recovery, return to the Ansible lifecycle so ownership and
  dependency ordering remain coherent.

## Supported lifecycle

After effective inputs, ownership, costs, and the displayed AWS scope are reviewed,
`../Ansible-modules-01/playbooks/create.yml` gates these stages:

1. apply the state bootstrap;
2. generate `remote-state.hcl`;
3. initialize or reconnect the main remote state;
4. apply Terraform-owned AWS infrastructure; and
5. continue the broader Ansible EKS/Jenkins/application create workflow.

The composable lower-level mutation flags remain false by default; `create.yml`
enables the reviewed sequence only after an exact interactive scope confirmation.
Teardown belongs to the separate dependency-ordered, cost-aware `destroy.yml`
workflow and retains remote state by default.
