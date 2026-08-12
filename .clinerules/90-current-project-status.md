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
- The Terraform-owned target stack in AWS account `058264247987`, region
  `us-east-1`, was destroyed successfully on 2026-08-12 after the interrupted
  fresh acceptance run. Main remote state is empty.
- The post-destroy read-only audit found no target EKS cluster, RDS instance, NAT
  gateway, load balancer, or application-data bucket. The separate versioned,
  encrypted remote-state bucket remains intentionally retained.
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
- The dependency-ordered destroy workflow has completed a live 63-resource
  teardown and post-destroy empty-state check. It uses project-local Terraform, Helm,
  kubectl, and an explicit ignored kubeconfig, verifies Terraform ownership and
  the target API endpoint, and requires exact interactive scope confirmation.
- The supported professor-facing lifecycle is now `bash setup.sh`, followed by
  `playbooks/create.yml`, with `playbooks/destroy.yml` as the separate default-off
  teardown. Setup installs pinned project-local tools and collections; create
  detects fresh-account state bootstrap, rejects unowned bucket collisions,
  displays billable scope, and requires one exact confirmation before enabling
  the composable lifecycle stages.
- Docker Hub credentials remain optional operator-bootstrap secrets. Default
  delivery requires none; BUILD_AND_DEPLOY prompts only when values are absent,
  verifies them, and maintains an idempotent per-value Ansible Vault block in the
  ignored mode-0600 `vault/local-environment.yml`.
- The clean option-2 acceptance run exposed and fixed two pre-delivery defects:
  Ansible 2.20 registry-value encryption now selects the validated vault password
  file/default vault ID explicitly, and cross-play facts use distinct namespaces
  so a file-stat dictionary cannot mask decrypted registry inputs. Setup and
  registry playbook syntax checks pass; the fixed path still needs a clean
  end-to-end rerun.
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
- In the interrupted fresh run, the guarded platform stage produced the ignored
  mode-0600 target kubeconfig, installed Jenkins chart `5.8.114` using
  project-local Helm `3.18.4`, and applied namespace deployer RBAC before the
  stack was cleanly destroyed.
- In that run, the ignored mode-0600 runtime handoff was generated, separate CI/CD
  jobs were seeded through the private Jenkins Service, and namespace-scoped
  `worker-db-secret` synchronization succeeded without exposing its value.
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
- Repository cleanup is complete in the working tree. Application source now
  lives at top-level `app/`; unused imported Ansible roles, obsolete app-role
  wrappers/examples, and superseded tracked workflows were removed. Professor
  lecture examples and historical scripts remain local-only in ignored archive
  paths; `K8S_EKS_PROGRESS.md` remains local-only at the repository root. Keep
  the CLI-auth helper in `scripts/` as a supported operator fallback.
- Shared non-secret lifecycle paths, namespaces, fixed object names, and Jenkins
  identifiers now have one Ansible source in `Ansible-modules-01/vars/project.yml`.
  Helm probes use named container ports, worker API port derives from the Service
  target port, and the fixed catalog object key is declared in worker values.
- A behavior-preserving readability pass consolidated worker environment-flag
  parsing and backend enum translation, clarified the frontend-content helper and
  teardown command structures, and corrected frontend public-entry-point comments.
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

1. Commit/review the clean-run fixes, then restart the final acceptance sequence
   from a clean local setup: `bash setup.sh`; `playbooks/create.yml` option 2
   `BUILD_AND_DEPLOY`; public user access and full application/service tests;
   evidence capture and documentation; guarded `playbooks/destroy.yml`; residual
   billable-resource audit.
2. The next create must be a full rerun, not a partial resume. The prior run
   stopped after Terraform, Jenkins, job seeding, and DB Secret synchronization;
   Jenkins registry synchronization and CI/CD were not reached successfully.
3. Ansible commands are standardized from `Ansible-modules-01/`; its single
   `ansible.cfg` uses the setup-installed `./collections` directory. Root-level
   command examples remain for the dedicated post-test documentation pass.
4. Replace TLS `require` with `verify-full` by deliberately packaging or mounting
   the AWS RDS CA bundle in a future rebuilt worker image.
5. Finish the assignment-complete README and architecture diagram before the
   acceptance sequence, then add the resulting validation evidence.
6. Decide during cleanup whether to retain or remove the authorized synthetic
   integration record
   and its versioned S3 backup; deletion requires separate explicit approval.

## Exact resume point

Resume by reviewing the committed clean-run fixes, deleting generated local setup
artifacts only with explicit approval, and rerunning the full acceptance sequence
without reordering it: clean local setup -> `bash setup.sh` -> `create.yml` option
2 -> user access and full application/service tests -> evidence documentation ->
destroy -> residual-cost audit. Main Terraform state is empty and the target
billable-resource audit is clean; only the retained state bucket remains. The
fresh run validated Docker Hub credentials before Terraform, created all 63 AWS
resources, installed private Jenkins, seeded CI/CD jobs, and synchronized the DB
Secret. It then stopped before CI because a registered file-stat dictionary
masked later registry variables; that namespace collision and the earlier
Ansible 2.20 vault-encryption ambiguity are fixed and syntax-checked but require
one clean end-to-end confirmation.

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
