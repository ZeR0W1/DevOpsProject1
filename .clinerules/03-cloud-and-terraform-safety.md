# Cloud and Terraform safety rules

## Cloud mutation boundary

- Treat every AWS, Kubernetes, Helm, and infrastructure mutation as intentional
  and scope-specific. Read-only inspection does not authorize later mutation.
- Never assume rollback can reverse AWS changes, destroyed or deleted data,
  credential exposure, infrastructure replacement, or external side effects.
- Reverify live cloud state read-only immediately before any decision that depends
  on it. Clearly label dated inventories as historical rather than current truth.
- Do not create, replace, resize, expose, or delete billable resources without a
  reviewed plan that identifies cost, dependencies, ownership, and teardown.

## Terraform state and ownership

- Terraform state is the ownership boundary. An empty state owns no live
  resources, even when configuration and live resource names match.
- Never run `terraform apply`, `terraform import`, `terraform destroy`, state
  mutation, backend migration, or implicit adoption unless the user explicitly
  authorizes that exact action after reviewing the migration/recreation plan.
- Never apply an empty or stale state against an existing environment as a shortcut
  to adoption. Choose deliberate import, deliberate recreation, or preservation
  outside Terraform and document the choice resource by resource.
- Inspect state only with read-only Terraform commands. Preserve state backups and
  do not edit state files manually.
- A speculative fresh-stack plan is validation evidence only. Review all effective
  inputs, backend and migration boundaries, provider reads, replacement behavior,
  costs, and sensitive output handling before running it; never apply the plan.

## Backend safety

- Define the Terraform S3 backend as partial configuration. Keep account- or
  environment-specific bucket/key/region values outside committed configuration.
- Use native S3 state locking with `use_lockfile = true`; do not introduce a new
  DynamoDB lock table unless a reviewed compatibility requirement demands it.
- Automate the dedicated remote-state bucket through the separate
  `terraform/state-bootstrap` root, orchestrated before the main stack by Ansible.
  The state bootstrap owns only state-storage infrastructure and uses separate
  local bootstrap state; it must not be confused with the application backend
  service or the Terraform-owned application-content bucket.
- Applying the state bootstrap and initializing or migrating the main backend are
  separate approved mutations. Main-stack teardown retains the state bucket by
  default; deleting it is a separate explicit retained-data decision.

## Secrets and inspection

- Never print or commit `terraform/terraform.tfvars`, state contents, plan files,
  credentials, database passwords, tokens, private keys, or sensitive outputs.
- Inspect effective Terraform inputs only through an explicit allow-list of
  non-secret names and redact unexpected sensitive values.
- Keep committed variable examples non-secret. Generate or retrieve real secrets
  at deployment time and store them only in approved secret systems.

## Protected external resources and Phase 1

- Preserve S3 bucket `quick-demo-058264247987-us-east-1-an`; it is an existing
  external resource and must not be altered or silently adopted. The application
  is moving to a new private Terraform-owned content/catalog bucket, so the primary
  README must explain why the legacy bucket remains outside current Terraform
  state and document its separate long-term ownership/cleanup boundary.
- Treat termination-protected CloudFormation stack `eksctl-learn-eks-cluster` as
  an external cleanup candidate, not as a `devops-app-eks` dependency or Terraform
  resource. Do not update, import, disable protection on, or delete it during Phase
  1. A later cleanup may remove it only after a fresh dependency/cost inventory and
  explicit approval of protection removal and stack deletion.
- Terraform Phase 1 is a temporary local-only modernization gate while the create
  flow moves from temporary shell/`eksctl` ownership to the intended
  Terraform-owned, Ansible-orchestrated lifecycle. Terraform apply and import
  remain absolutely prohibited until the user explicitly approves leaving this
  phase after reviewing state/backend and import-versus-recreation boundaries.
- Phase 1 may use formatting, validation, static analysis, read-only state
  inspection, carefully allow-listed non-secret input inspection, documentation,
  and an explicitly approved no-apply plan when its prerequisites are coherent.