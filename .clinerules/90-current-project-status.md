# Current project status

Purpose: compact recovery record for `/home/geeta/Project1`.

This file contains only current truth, active blockers, immediate work, and the
exact resume point. Durable workflow, architecture, ownership, and cloud-safety
rules live in the lower-numbered `.clinerules` files. Historical milestones and
superseded evidence belong in `misc/recovery/PROJECT_HISTORY.md`.

## Current environment and ownership state

- Terraform Phase 1 ended by explicit user approval on 2026-08-11.
- The separate retained, versioned, encrypted state bucket was created and the
  main stack now uses its S3 backend with native lock files.
- The fresh Terraform-owned target stack was applied in AWS account
  `058264247987`, region `us-east-1`. Remote state owns 63 resources and a final
  read-only plan returned zero drift.
- Target EKS `doa-staging-eks` 1.34 and its three-node private `t3.medium` group
  are ACTIVE. RDS PostgreSQL 17.6 on `db.t4g.micro` is available and private.
- EKS authentication is `API_AND_CONFIG_MAP`; the Jenkins deployer access entry,
  worker/CI/deployer Pod Identity associations, NAT path, application S3/SNS,
  Secrets Manager secret, and DB security boundaries exist in Terraform state.
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
- Terraform now explicitly configures EKS API authentication required by the
  deployer access entry. DB ingress rules use consistent standalone Terraform
  ownership for the approved admin CIDR and EKS-node PostgreSQL access.
- Guarded Ansible lifecycle orchestration is present with mutation stages
  disabled by default.
- Worker Pod Identity, EBS CSI IRSA, and separate least-privilege Jenkins CI/CD
  Pod Identity roles/associations are active with the Terraform-owned target.
- A dependency-ordered destroy workflow exists and has only been
  statically/default-run validated. It now uses project-local Terraform, Helm,
  kubectl, and an explicit ignored kubeconfig, verifies Terraform ownership and
  the target API endpoint, and requires exact interactive scope confirmation.
- The supported professor-facing lifecycle is now `./setup.sh`, followed by
  `playbooks/create.yml`, with `playbooks/destroy.yml` as the separate default-off
  teardown. Setup installs pinned project-local tools and collections; create
  detects fresh-account state bootstrap, rejects unowned bucket collisions,
  displays billable scope, and requires one exact confirmation before enabling
  the composable lifecycle stages.
- Docker Hub credentials remain optional operator-bootstrap secrets. Default
  delivery requires none; BUILD_AND_DEPLOY prompts only when values are absent,
  verifies them, and maintains an idempotent per-value Ansible Vault block in the
  ignored mode-0600 `vault/local-environment.yml`.
- Worker integration implements PostgreSQL-first reads and
  writes, JSON export to fixed S3 object `instances.json`, metadata-only SNS
  notifications, error propagation, and Helm ConfigMap/Secret wiring.
- Focused worker tests pass (`7 passed`), worker Helm lint/render checks pass,
  and source-controlled test dependencies are installed by the active EKS CI
  pipeline from `src/requirements-test.txt`. Live RDS/S3/SNS integration is
  runtime-validated through one authorized synthetic record.
- Frontend runtime-content work enables S3 versioning, CI
  seed-if-missing/explicit reset of fixed `index.html`, CD `FULL` and
  `CONTENT_ONLY` modes, a CD-owned `frontend-runtime-content` ConfigMap, and a
  frontend-only read-only directory mount/rolling activation. The helper, chart,
  Terraform, and focused pipeline assertions pass locally; FULL cloud/Jenkins
  delivery and external frontend content serving are validated.
- Backend non-secret runtime configuration now has one worker Service DNS/port
  source, an immutable container bind contract on port 8000, and no ignored
  `API_*` Helm variables. All three chart default repositories match CI/CD, and
  focused lint/render assertions pass with immutable tags.
- The guarded platform stage produced the ignored mode-0600 target kubeconfig,
  installed Jenkins chart `5.8.114` using project-local Helm `3.18.4`, and applied
  namespace deployer RBAC. Jenkins is ready, private ClusterIP-only, and uses a
  bound 8 GiB PVC; Terraform retains IAM and workload-identity ownership.
- The ignored mode-0600 runtime handoff exists, separate CI/CD jobs were seeded
  through the private Jenkins Service, and namespace-scoped `worker-db-secret`
  synchronization succeeded without exposing its value.
- CI now supports `DEPLOY_DEFAULT` and `BUILD_AND_DEPLOY` in the existing job.
  Default mode uses public `zer0w1` images at promoted immutable tag
  `3-c896ff25891a`, never needs registry credentials, seeds only missing
  `index.html`, and hands off to standalone FULL CD. `DEPLOY_IMAGE_TAG` may
  select another immutable tag without enabling build/push. Build mode derives
  repositories from the operator's Docker Hub namespace and retains CI
  build/push/check stages.
- A default-off guarded registry stage privately prompts for operator Docker Hub
  credentials, stores them in a namespace Secret with suppressed output, and uses
  a hardened in-cluster Jenkins API Job to create or update `dockerhub-creds`.
  Two-mode orchestration, lint, syntax, default-off, and focused invariants pass;
  the credential stage and both delivery paths have been live-run.
- The frontend `LoadBalancer` Service remains the only public application endpoint.
  Jenkins remains ClusterIP-only with no public load balancer or Ingress; an
  operator may use `kubectl port-forward` only when UI access is needed.
- Authorized Jenkins CI build 3 built and pushed all three public images with
  immutable tag `3-c896ff25891a`. Corrected standalone CD build 2 succeeded, and
  credential-free override CI build 4 plus CD build 3 succeeded with that tag.
- Frontend, backend, and worker each run two ready replicas. Frontend external
  HTTP is verified through its AWS load balancer; backend, worker, and Jenkins
  remain ClusterIP-only.
- Worker PostgreSQL uses TLS `require` because the current image has no bundled
  RDS CA file. An authorized synthetic record verified RDS-primary reads/writes,
  versioned S3 `instances.json`, and one metadata-only SNS publication.
- Authorized Ansible job seeding now succeeds. The generic job helper and both
  EKS job wrappers are eligible to move to `scripts/legacy/` after explicit
  deletion/move approval; keep the CLI-auth helper in `scripts/` as supported.
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

1. Execute the final acceptance sequence in this exact order: repository cleanup;
   `./setup.sh` from a clean local setup; `playbooks/create.yml`; public user
   access and full application/service functionality tests; evidence capture and
   documentation; guarded `playbooks/destroy.yml`; residual billable-resource
   audit.
2. During that sequence, reseed the promoted default job definition before the
   delivery run; live jobs currently contain the verified override-capable logic
   but the promoted fallback exists only in the local Jenkinsfile.
3. Replace TLS `require` with `verify-full` by deliberately packaging or mounting
   the AWS RDS CA bundle in a future rebuilt worker image.
4. Finish the assignment-complete README and architecture diagram before the
   acceptance sequence, then add the resulting validation evidence.
5. Decide during cleanup whether to retain or remove the authorized synthetic
   integration record
   and its versioned S3 backup; deletion requires separate explicit approval.

## Exact resume point

Resume with repository cleanup. Then follow the final acceptance sequence without
reordering it: clean local setup -> setup -> create -> user access and full
application/service tests -> evidence documentation -> destroy -> residual-cost
audit. Treat the current working tree as the integrated implementation to review,
not unrelated work to preserve automatically. Before deleting or moving any
obsolete asset, obtain explicit path approval. Before the acceptance delivery,
reseed the local promoted fallback `3-c896ff25891a`. The live target currently
runs that tag, all three application workloads are ready, the frontend load
balancer is public, and Jenkins/backend/worker remain private.

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
