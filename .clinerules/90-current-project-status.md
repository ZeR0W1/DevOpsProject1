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
- The external S3 bucket `quick-demo-058264247987-us-east-1-an` remains present
  outside the current Terraform ownership boundary. The previously protected
  CloudFormation stack `eksctl-learn-eks-cluster` was independently verified
  absent after teardown; the project teardown did not target that stack.
- Existing external resources may collide with names proposed for the future
  Terraform-owned stack; relevant names must be reverified read-only before
  relying on them.

## Current implementation state

- Assignment 4 work continues on local branch `aws4-jenkins-cicd`, branched from
  Assignment 3 commit `db8f9f7`. The hardening checkpoint is commit `6b6706b` and
  was explicitly pushed to `origin/aws4-jenkins-cicd`; the lifecycle-organization
  and destroy-hardening checkpoint is commit `53ebe56`; acceptance fixes through
  `8dee0af` and lifecycle checkpoint `b17dc86` are also pushed. The resumed
  authorized E2E created all three application releases from source-built immutable
  tag `2-8dee0af765a0`; standalone CD builds 1 and 2 succeeded, all workloads are
  healthy, public routing checks pass, and an approved worker record verified RDS
  persistence, encrypted S3 synchronization, and the synchronous SNS publish path.
  The push of `b17dc86` triggered CI build 5 through the live webhook; it completed
  `SUCCESS` without triggering another standalone CD build. The authorized normal
  teardown then completed without an application-data backup: the webhook and
  application objects were removed, the dedicated cluster was purged, all 77
  Terraform-owned addresses were destroyed, and the self-signed certificate was
  deleted. Main state is empty; the separate state bucket is retained.
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
- CI/CD pipeline compliance includes mandatory source-build Trivy, published
  JUnit results, failure-safe credential cleanup, CI-to-CD commit/build/digest
  traceability, archived CD failure diagnostics, bounded hardened agent Pods, and
  a real frontend-to-backend/worker HTTP smoke test in standalone CD. Checkpoint
  `51e570b` also makes Bandit and Flake8 blocking over explicit first-party Python
  files and adds a scoped Flake8 policy.
- Checkpoint `51e570b` enables EKS VPC CNI
  NetworkPolicy enforcement; adds default-deny-by-selection ingress/egress
  policies for frontend, backend, and worker; enables `RuntimeDefault` seccomp and
  read-only root filesystems with only required `emptyDir` mounts; and disables
  ServiceAccount token automount for frontend/backend while retaining the worker
  token for EKS Pod Identity. Root and Helm documentation now describe the
  Kubernetes boundary and layered NetworkPolicy/security-group/IAM controls.
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
- Clone/fork reproducibility and the credential preflight fix are pushed through
  `8dee0af`. Setup detects and confirms a GitHub HTTPS repository and
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
- Cloud teardown exposed one additional lifecycle defect: the generic custom-
  resource sweep deleted EKS VPC CNI `CNINode` objects while `aws-node` remained
  active, so the system controller immediately recreated them and the purge stopped
  safely before Terraform. The local fix preserves only
  `cninodes.vpcresources.k8s.aws` for the Terraform-owned EKS/CNI lifecycle while
  retaining fail-closed deletion for all other custom resources. Five purge tests,
  Python compilation, and Git whitespace validation pass; the corrected rerun
  completed the full teardown. The fix is pushed in checkpoint `e0946df`.
- Full local Terraform formatting/validation, all Ansible playbook syntax checks,
  production-profile `ansible-lint`, Helm lint/render for all three charts, shell
  syntax, deterministic CIDR checking, Git whitespace checks, and seven worker
  tests pass. Focused Bandit and Flake8 checks also pass for the current hardening
  edits. Both Jenkinsfiles passed the pinned local controller's authoritative
  Declarative Pipeline validator at the previous checkpoint; the local validator
  artifact is currently absent, so the current Jenkinsfile edit still requires
  authoritative Declarative validation in the next clean E2E.
- Resumed cloud acceptance exposed two final defects: successful Kaniko/CD work
  was marked CI failure when post-stage cleanup tried to exec into the exited
  Kaniko container, and create accepted ALB health without requiring the exact CI
  result. Checkpoint `b17dc86` makes cleanup failure-safe and makes the in-cluster
  trigger follow its queue item and require the exact build to finish `SUCCESS`
  within a bounded ten-minute Job. The webhook-triggered CI build 5 passed, so the
  cleanup fix is cloud-accepted; the exact create-lifecycle result gate remains to
  be exercised during the next clean E2E.
- The pushed acceptance checkpoint also extracts the CI trigger,
  Jenkins job seeding, registry credential configuration, and webhook Groovy
  programs from oversized inline playbook blocks into project-owned helpers.
  Focused Python/shell compilation, four-playbook syntax checks, production lint,
  helper-reference inspection, and Git whitespace checks pass. A confirmation-
  gated login helper prints the private Jenkins credentials only to the operator
  terminal and is documented with terminal-scrollback precautions.
- The command-by-command E2E create/webhook/CI/CD/verification/teardown checklist
  has been reviewed. The Assignment 4 hardening commit and push of only
  `aws4-jenkins-cicd` were explicitly authorized; Jenkins is seeded against that
  remote acceptance branch.
- The current clean E2E stack is live from pushed checkpoint `f8f6a9c`. CI build
  7 and CD build 3 created common Helm revision 2 from immutable tag
  `3-ad78fd6161cf`; queue-correlation and rollback post-verification defects found
  during acceptance were fixed in checkpoints `6faf78b` and `f8f6a9c`. The
  corrected guarded rollback was cloud-accepted by standalone CD build 5:
  frontend, backend, and worker now have deployed revision 4 entries described
  as `Rollback to 1`, remain 2/2 ready on the same immutable images, and public
  frontend, backend health, and machines routing checks pass. Webhook CI build 9
  also completed `SUCCESS` without application deployment.
- A local image-remediation pass found fixable HIGH/CRITICAL findings
  in deployed tag `3-ad78fd6161cf`. Refreshed Alpine bases, patched Python
  packaging tools, FastAPI `0.135.0`/Starlette `1.6.0`, nested-venv Docker-context
  exclusion, UID/GID `10001`, and matching writable-volume group ownership reduce
  all three rebuilt local images to zero HIGH/CRITICAL findings in Trivy `0.57.1`.
  Seven worker tests, blocking Flake8/Bandit, hardened non-root/read-only runtime
  smoke tests, and Helm lint/render assertions pass. These images are local only
  and have not been published or deployed.
- The untracked `k8s/logging/` directory is unrelated class-lab work; preserve it
  untouched and exclude it from Assignment 4 commits and acceptance reasoning.
- During current acceptance work, Jenkins intentionally watches only
  `aws4-jenkins-cicd` while `main` carries the default-branch scheduled workflow
  without triggering project CI. After acceptance is complete, change the seeded
  Jenkins CI/CD SCM refs and related target-branch defaults from
  `aws4-jenkins-cicd` to `main`, then validate that intentional `main` pushes are
  the production CI trigger.

## Immediate work queue

1. Review and explicitly authorize immutable image publication and standalone CD.
2. After any approved deployment verification, run the separately authorized
   stage-gated teardown path.
3. After final teardown, check out `main`, rerun setup so the
   ignored watched-branch selection becomes `main`, and validate the production
   trigger.

## Exact resume point

Resume from pushed checkpoint `f8f6a9c` on local branch `aws4-jenkins-cicd` and
the matching clean clone `/home/geeta/Project1-e2e-clean`. The authorized E2E
stack is live in account `058264247987`, region `us-east-1`; standalone CD build
5 successfully completed the guarded rollback to common historical revision 1,
recorded as deployed Helm revision 4 for all three releases. Workloads are 2/2
ready on tag `3-ad78fd6161cf`; public checks pass. Preserve untracked
`k8s/logging/` and `scripts/recreate_state_bucket_boundary.sh`. No teardown or
other cloud mutation is authorized beyond an explicitly approved next stage.
Local image-remediation edits are validated; local remediated images have not
been published or deployed.

## Status-file maintenance rule

Keep this file short. At the end of a work session:

- update only current truth, active blockers, immediate work, and the resume
  point;
- remove or replace superseded current-state statements;
- move completed milestones, dated evidence, old inventories, and historical
  implementation detail to `misc/recovery/PROJECT_HISTORY.md`;
- do not accumulate chronological logs here.
