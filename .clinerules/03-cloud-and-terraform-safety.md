# Cloud and Terraform safety rules

## Cloud mutation boundary

- Treat every AWS, Kubernetes, Helm, and infrastructure mutation as intentional
  and scope-specific. Read-only inspection does not authorize later mutation.
- Never assume rollback can reverse AWS changes, destroyed or deleted data,
  credential exposure, infrastructure replacement, or external side effects.
- Reverify live cloud state read-only immediately before any decision that
  materially depends on it.
- Do not create, replace, resize, expose, or delete billable resources without a
  reviewed plan covering cost, dependencies, ownership, and teardown.

## Terraform state and ownership

- Terraform state is the ownership boundary. An empty state owns no live
  resources, even when configuration and live resource names match.
- Never run `terraform apply`, `terraform import`, `terraform destroy`, state
  mutation, backend migration, or implicit adoption unless the user explicitly
  authorizes that exact action after reviewing the relevant ownership and
  migration/recreation boundary.
- Never apply an empty or stale state against an existing environment as a
  shortcut to adoption.
- Inspect state only with read-only Terraform commands. Preserve state backups
  and do not edit state files manually.
- A speculative fresh-stack plan is validation evidence only. Review effective
  inputs, backend/state boundaries, provider reads, replacement behavior, cost,
  and sensitive-output handling before running it; never apply that speculative
  plan. Generate and review a new plan for any later authorized deployment.

## Backend safety

- Define the Terraform S3 backend as partial configuration. Keep account- and
  environment-specific backend values outside committed configuration.
- Use native S3 state locking with `use_lockfile = true`; do not introduce a new
  DynamoDB lock table unless a reviewed compatibility requirement demands it.
- Keep the dedicated remote-state bootstrap separate from the main Terraform
  stack and application-data infrastructure.
- Treat state-bootstrap apply, main-backend initialization/migration, and
  main-stack apply as separate mutations requiring their own approval.
- Retain the remote-state bucket during normal main-stack teardown unless the
  user explicitly approves its separate deletion.

## Secrets and inspection

- Never print or commit `terraform/terraform.tfvars`, state contents, plan files,
  credentials, database passwords, tokens, private keys, or sensitive outputs.
- Inspect effective Terraform inputs only through an explicit allow-list of
  non-secret names and redact unexpected sensitive values.
- Keep committed variable examples non-secret. Generate or retrieve real secrets
  at deployment time and store them only in approved secret systems.

## Protected external resources and Phase 1

- Do not alter, import, adopt, or delete resources identified by the current
  project status as externally owned or protected unless the user explicitly
  changes that ownership boundary.
- During Terraform Phase 1, treat the work as a guarded modernization/recreation
  process. While Phase 1 remains active, do not run `terraform apply`,
  `terraform import`, backend migration, or state mutation. These actions may
  proceed only after the user explicitly approves leaving Phase 1 following
  review of state/backend, ownership, cost, and recreation/import boundaries. Do
  not convert temporary shell/`eksctl` ownership into Terraform ownership
  implicitly.