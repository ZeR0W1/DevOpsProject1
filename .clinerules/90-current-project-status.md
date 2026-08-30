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
- The configured main S3 backend is shared with the sister workspace
  `/home/geeta/Project1-prometheus-lab`. The monitoring-lab teardown completed in
  AWS account `058264247987`, region `us-east-1`, after exact authorized deletion
  of one verified orphan EKS service-created security group. Shared main Terraform
  state is empty and the former VPC is absent. Only the separate versioned,
  encrypted remote-state bucket is intentionally retained.
- The old external `devops-app-eks` lecture-lab cluster was verified absent in
  `us-east-1` on 2026-08-29 and is no longer an active ownership boundary.
- Any future Terraform-owned stack remains a parallel recreation,
  not an import/adoption of the live environment.
- The external S3 bucket `quick-demo-058264247987-us-east-1-an` and protected
  CloudFormation stack `eksctl-learn-eks-cluster` remain outside the current
  Terraform ownership boundary.
- Existing external resources may collide with names proposed for the future
  Terraform-owned stack; relevant names must be reverified read-only before
  relying on them.

## Current implementation state

- Assignment 4 work continues on local branch `aws4-jenkins-cicd`, branched from
  Assignment 3 commit `db8f9f7`. The hardening checkpoint is commit `6b6706b` and
  was explicitly pushed to `origin/aws4-jenkins-cicd`; the lifecycle-organization
  and destroy-hardening checkpoint is commit `53ebe56` and is also pushed. The
  first authorized E2E create produced the Terraform-owned stack and Jenkins but
  stopped before application delivery when the encrypted GitHub token proved to
  be a stale placeholder. That partial stack remains live pending guarded resume.
- The Assignment 4 webhook direction is a direct GitHub-to-Jenkins webhook, not
  the discarded Lambda/SQS relay. The planned controls are the current GitHub
  `hooks` CIDR allowlist, GitHub webhook HMAC validation, private Jenkins UI
  access, and separate SCM-backed CI/CD jobs.
- The approved TLS concept offers two create-time choices: an existing Route 53
  public hosted zone with Terraform-managed ACM DNS validation and GitHub SSL
  verification enabled, or an explicitly documented domainless lab fallback
  using an Ansible-generated/imported self-signed certificate with GitHub SSL
  verification disabled. Current trusted-mode scope is Route 53 only, but inputs
  should preserve a clean future external-DNS validation extension point.
- The approved shared public-entry design is locally implemented through a
  Terraform-owned ALB: frontend defaults to fixed NodePort `32081`; the exact
  `/github-webhook/` path from refreshed GitHub IPv4 hook CIDRs is forwarded to a
  separate Jenkins NodePort `32080`; all other Jenkins paths fall through to the
  frontend. The normal Jenkins Service remains ClusterIP-only. GitHub CIDRs are
  batched two per listener rule.
- The local CIDR lifecycle is implemented: committed applied snapshot,
  deterministic read-only checker, pre-push warning, issue-only GitHub Action,
  and `bash setup.sh refresh-github-hooks`. Refresh requires an already initialized
  S3 backend, restricts a saved plan to ALB webhook listener rules, requires exact
  confirmation, and redelivers at most the latest failed target-branch push.
- CI/CD pipeline compliance edits are local: mandatory source-build Trivy,
  published JUnit results, failure-safe credential cleanup, CI-to-CD commit/build/
  digest traceability, archived CD failure diagnostics, bounded hardened agent
  Pods, and a real frontend-to-backend/worker HTTP smoke test in standalone CD.
- The custom CI agent now uses a digest-pinned Jenkins inbound-agent base. With
  explicit user approval, image
  `zer0w1/devops-project1-jenkins-agent:eks-python-v2` was built and pushed to
  Docker Hub at manifest digest
  `sha256:c226666c65258fe952bc44375f489255d64845a20e3d6f55c297e4d7bd09050d`;
  local verification confirmed UID 1000 and the required tool entry points.
- The create lifecycle now derives and verifies the Terraform-owned public ALB
  URL instead of reusing the private Jenkins service URL. CI records the Jenkins
  trigger cause and resolved Git author identity, passes them to standalone CD,
  and CD archives them with commit, build, tag, and digest traceability. Jenkins
  JCasC explicitly disables signup and anonymous read while retaining CSRF crumbs.
- The create playbook retains its interactive `CREATE` gate by default and also
  supports exact `CREATE_CONFIRMATION_OVERRIDE=CREATE` preauthorization for the
  reviewed unattended runner; all other values are rejected by the same assertion.
- Clone/fork reproducibility and the credential preflight fix are local and await
  checkpoint approval. Setup detects and confirms a GitHub HTTPS repository and
  watched branch, writes them to ignored mode-0600 `vars/project.local.yml`, and
  verifies the hidden fine-grained token can read that repository's webhooks.
  Create revalidates the same contract before AWS/Terraform work; webhook create,
  removal, CIDR refresh/redelivery, Jenkins SCM/parameter defaults, and the
  pre-push warning all consume it. Source-build image repositories derive from
  the encrypted operator Docker Hub username; promoted defaults remain unchanged.
- Main Terraform apply failures now stop the lifecycle before EKS/Jenkins and
  application stages, preserve remote-state progress, report only state-owned
  addresses, and direct the operator to resolve the smallest reviewed conflict or
  provider issue before rerunning the idempotent create lifecycle. No automatic
  import, delete, rename, retry, or rollback occurs.
- Top-level `playbooks/create.yml` and `playbooks/destroy.yml` are now the guarded
  operator entry points. Internal create stages are grouped under
  `playbooks/create/`; internal destroy stages are standalone imported playbooks
  under `playbooks/destroy/`. Local setup and CIDR maintenance helpers are grouped
  under `playbooks/create/setup/`.
- Destroy normal/resume mode selection, exact `DESTROY`, scope display, and state
  ownership checks remain in the wrapper. The ordered normal lifecycle performs
  optional backup, exact webhook removal, dedicated-cluster purge, application
  object deletion, full Terraform destroy, state-empty verification, and released
  self-signed-certificate cleanup. Resume runs only the shared Terraform stage.
- Terraform destroy failures use uniform human-readable diagnostics for every
  resource type: narrowly classified transient provider/network errors receive one
  delayed retry; final errors have credential-like patterns redacted, remaining
  state addresses are displayed, partial state is preserved, and no generic
  out-of-state AWS deletion is attempted.
- Full local Terraform formatting/validation, all Ansible playbook syntax checks,
  production-profile `ansible-lint`, Helm lint/render for all three charts, shell
  syntax, deterministic CIDR checking, Git whitespace checks, and seven worker
  tests pass. Both current Jenkinsfiles also pass the pinned local controller's
  authoritative Declarative Pipeline validator.
- End-to-end cloud acceptance remains pending by user decision and will follow
  the approved hardening checkpoint; any findings will be recorded in a separate
  fix commit.
- The command-by-command E2E create/webhook/CI/CD/verification/teardown checklist
  has been reviewed. The Assignment 4 hardening commit and push of only
  `aws4-jenkins-cicd` were explicitly authorized; Jenkins is seeded against that
  remote acceptance branch.
- The untracked `k8s/logging/` directory is unrelated class-lab work; preserve it
  untouched and exclude it from Assignment 4 commits and acceptance reasoning.
- During current acceptance work, Jenkins intentionally watches only
  `aws4-jenkins-cicd` while `main` carries the default-branch scheduled workflow
  without triggering project CI. After acceptance is complete, change the seeded
  Jenkins CI/CD SCM refs and related target-branch defaults from
  `aws4-jenkins-cicd` to `main`, then validate that intentional `main` pushes are
  the production CI trigger.

## Immediate work queue

1. Obtain explicit approval, then commit and push only the local credential-
   preflight and clone/fork-reproducibility checkpoint to `aws4-jenkins-cicd`.
2. Resume the partial create only with a separate explicit mutation approval,
   complete delivery/verification, then run the reviewed teardown.
3. Run the clean create/webhook/CI/CD/verification/teardown E2E with stage-specific
   approvals.
4. After acceptance and teardown, check out `main`, rerun setup so the ignored
   watched-branch selection becomes `main`, and validate the production trigger.

## Exact resume point

Resume by obtaining authorization for the local reproducibility/preflight
checkpoint commit and push, excluding untracked `k8s/logging/`, then obtain a
separate approval before rerunning create against the partial stack. The current
ignored SCM selection resolves to `ZeR0W1/DevOpsProject1` branch
`aws4-jenkins-cicd`; a real cancellation preflight validated the refreshed token's
webhook access and reached the scope display with `changed=0` before stopping.
All 23 playbooks pass syntax checks and production-profile `ansible-lint`;
Terraform formatting/validation, four purge tests, Python compile, shell syntax,
CIDR checking, Helm lint/render, seven worker tests, and Git whitespace checks
pass. Reverify current Terraform/Kubernetes ownership and target-name state
read-only immediately before resumed create. Preserve untracked
`k8s/logging/` class-lab files. Do not commit, push, plan, apply, destroy,
reinitialize a backend, or mutate cloud/GitHub state without explicit approval.

## Status-file maintenance rule

Keep this file short. At the end of a work session:

- update only current truth, active blockers, immediate work, and the resume
  point;
- remove or replace superseded current-state statements;
- move completed milestones, dated evidence, old inventories, and historical
  implementation detail to `misc/recovery/PROJECT_HISTORY.md`;
- do not accumulate chronological logs here.
