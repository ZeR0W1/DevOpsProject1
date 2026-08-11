# Current project status

Purpose: compact recovery record for `/home/geeta/Project1`.

This file contains only current truth, active blockers, immediate work, and the
exact resume point. Durable workflow, architecture, ownership, and cloud-safety
rules live in the lower-numbered `.clinerules` files. Historical milestones and
superseded evidence belong in `misc/recovery/PROJECT_HISTORY.md`.

## Current environment and ownership state

- Terraform Phase 1 remains active.
- The live `devops-app-eks` environment remains externally owned by
  `eksctl`/CloudFormation and outside Terraform state. It is a lecture-lab cluster
  containing only a Jenkins controller/plugins setup; disregard it when reasoning
  about target project architecture and do not mutate it for project work.
- The future Terraform-owned stack is still intended as a parallel recreation,
  not an import/adoption of the live environment.
- The external S3 bucket `quick-demo-058264247987-us-east-1-an` and protected
  CloudFormation stack `eksctl-learn-eks-cluster` remain outside the current
  Terraform ownership boundary.
- Existing external resources may collide with names proposed for the future
  Terraform-owned stack; relevant names must be reverified read-only before
  relying on them.

## Current local setup state

- `playbooks/setup_local_environment.yml` was repaired and successfully run.
- Ignored mode-0600 `.vault-password` and
  `vault/local-environment.yml` now exist.
- `PREPARE_TERRAFORM_INPUTS=true` with
  `ANSIBLE_VAULT_PASSWORD_FILE=.vault-password` successfully regenerated the
  ignored `terraform/terraform.tfvars` and verified the AWS credential chain.
- The setup and input-preparation runs completed without AWS infrastructure
  mutation.
- Effective non-secret Terraform inputs were inspected through an allow-list.
- Current reviewed deployment decisions include Kubernetes `1.34`, three
  desired/minimum `t3.medium` nodes (maximum four), and PostgreSQL `17.6` on
  `db.t4g.micro` with 20 GiB storage.
- Local private input files and effective `terraform.tfvars` were verified mode
  `0600`.

## Current implementation state

- Main Terraform configuration, partial S3 backend, and separate
  `terraform/state-bootstrap` root are present.
- Guarded Ansible lifecycle orchestration is present with mutation stages
  disabled by default.
- Worker Pod Identity, EBS CSI IRSA, and separate least-privilege Jenkins CI/CD
  Pod Identity roles/associations are implemented in Terraform configuration.
  The deployer EKS access entry is defined. The post-infrastructure Ansible create
  stages remain incomplete.
- A dependency-ordered destroy workflow exists and has only been
  statically/default-run validated.
- Worker integration implements PostgreSQL-first reads and
  writes, JSON export to fixed S3 object `instances.json`, metadata-only SNS
  notifications, error propagation, and Helm ConfigMap/Secret wiring.
- Focused worker tests pass (`7 passed`), worker Helm lint/render checks pass,
  and source-controlled test dependencies are installed by the active EKS CI
  pipeline from `src/requirements-test.txt`. Live RDS/S3/SNS integration is not
  yet runtime-validated.
- Frontend runtime-content work enables S3 versioning, CI
  seed-if-missing/explicit reset of fixed `index.html`, CD `FULL` and
  `CONTENT_ONLY` modes, a CD-owned `frontend-runtime-content` ConfigMap, and a
  frontend-only read-only directory mount/rolling activation. The helper, chart,
  Terraform, and focused pipeline assertions pass locally; no cloud/Jenkins run
  has validated the path.
- Backend non-secret runtime configuration now has one worker Service DNS/port
  source, an immutable container bind contract on port 8000, and no ignored
  `API_*` Helm variables. All three chart default repositories match CI/CD, and
  focused lint/render assertions pass with immutable tags.
- Guarded application runtime preparation now maps reviewed Terraform outputs to
  an ignored mode-0600 non-password handoff and can independently synchronize
  the namespace-scoped `worker-db-secret` from Secrets Manager. FULL CD consumes
  the real RDS/S3/SNS settings and requires that Secret to exist. Local syntax,
  default-off, allow-list, wrapper, and worker chart checks pass; neither guarded
  path has been cloud-run.
- Guarded EKS platform preparation now consumes Terraform cluster outputs, writes
  an ignored mode-0600 target kubeconfig, verifies its API endpoint, installs the
  pinned Jenkins chart through `kubernetes.core.helm`, and applies only Kubernetes
  deployer RBAC. IAM, access-entry, and Pod Identity ownership remains Terraform.
  The stage is default-off, confirmation-gated, and locally linted/validated; it
  has not been cloud-run.
- Ansible-native Jenkins job seeding now renders Jenkins job XML directly from
  the separate CI/CD Jenkinsfiles, consumes only the prepared non-secret runtime
  handoff, and launches a hardened short-lived in-cluster Job that reads the chart
  admin Secret without exporting credentials. It seeds CD before CI through the
  private ClusterIP Service. Pinned-chart assumptions and default-off syntax,
  render, and lint checks pass; no Kubernetes Job or Jenkins API call has run.
- The frontend `LoadBalancer` Service remains the only public application endpoint.
  Jenkins remains ClusterIP-only with no public load balancer or Ingress; an
  operator may use `kubectl port-forward` only when UI access is needed.
- Keep the transitional Jenkins job shell helpers in place until an authorized
  Ansible seeding run succeeds. After that evidence exists, move the generic job
  helper and both EKS job wrappers to `scripts/legacy/`; keep the CLI-auth helper
  in `scripts/` as a supported standalone credential utility.
- Application integration is not hand-in complete.

## Current naming-inventory state

- The read-only AWS name-collision inventory completed on 2026-08-10.
- No exact collision was found for the main stack's derived application S3
  bucket, EKS cluster, SNS topic, CloudWatch alarm, RDS instance, DB subnet
  group, Secrets Manager secret, or IAM role names.
- The existing externally owned SNS topic is named `DOAworker`; Terraform's
  effective topic name is `doa-staging-DOAworker`, so the earlier apparent
  collision was a false positive caused by checking the unprefixed input rather
  than the module-derived resource name.
- No main-stack naming-input change is currently required. Reverify live names
  before a future reviewed deployment because external state can change.

## Immediate work queue

1. Complete the guarded Ansible create lifecycle after infrastructure:
   initial S3 content -> application runtime/Secret preparation -> standalone CD
   invocation and verification.
2. Implement and verify the public frontend `LoadBalancer`; keep Jenkins private
   and verify only the optional operator `kubectl port-forward` UI path.
3. Review the Terraform backend/state/cost boundary before any plan or mutation,
   then collect live RDS/S3/SNS evidence only during an authorized deployment.
4. Finish the assignment-complete README, architecture diagram, validation
   evidence, and hand-in readiness work.

## Exact resume point

Resume with guarded create-flow invocation after job seeding: orchestrate initial
`index.html` seeding, application runtime/Secret preparation, and standalone FULL
CD execution through the private Jenkins controller without merging CI/CD
ownership.

The focused worker, frontend runtime-content, and backend configuration slices are
locally validated; do not repeat dependency setup or the name-collision inventory
unless relevant state changes. Preserve PostgreSQL-primary storage, fixed
`instances.json` backup, metadata-only SNS, fixed versioned `index.html`, separate
Pod Identities, CD-owned frontend ConfigMap, Kubernetes Secret boundaries, and the
non-password runtime handoff when wiring the remaining Ansible lifecycle.

## Status-file maintenance rule

Keep this file short. At the end of a work session:

- update only current truth, active blockers, immediate work, and the resume
  point;
- remove or replace superseded current-state statements;
- move completed milestones, dated evidence, old inventories, and historical
  implementation detail to `misc/recovery/PROJECT_HISTORY.md`;
- do not accumulate chronological logs here.
