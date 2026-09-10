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
  `/home/geeta/Project1-prometheus-lab`. The current Assignment 4 final-evidence
  stack is active in AWS account `058264247987`, region `us-east-1`. Its initialized
  main state owns 77 addresses, and the target EKS cluster currently runs all three
  application Deployments. The explicitly authorized local handoff copied the
  authoritative encrypted environment, Terraform inputs, application runtime, and
  kubeconfig from `/home/geeta/Project1-e2e-clean` to `/home/geeta/Project1` without
  changing remote state, infrastructure, or Jenkins. The regular checkout is now
  the lifecycle operator; retain the clean checkout unchanged as a fallback.
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

- Assignment 4 work continues on local branch `aws4-jenkins-cicd`. The resumed
  authorized E2E created all three application releases from source-built immutable
  tag `2-8dee0af765a0`; standalone CD builds 1 and 2 succeeded, all workloads are
  healthy, public routing checks pass, and an approved worker record verified RDS
  persistence, encrypted S3 synchronization, and the synchronous SNS publish path.
  Webhook-triggered CI build 5 completed
  `SUCCESS` without triggering another standalone CD build. The authorized normal
  teardown then completed without an application-data backup: the webhook and
  application objects were removed, the dedicated cluster was purged, all 77
  Terraform-owned addresses were destroyed, and the self-signed certificate was
  deleted. Main state is empty; the later authorized absolute-zero reset also
  removed the separate state bucket.
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
  a real frontend-to-backend/worker HTTP smoke test in standalone CD. CI also makes
  Bandit and Flake8 blocking over explicit first-party Python
  files and adds a scoped Flake8 policy.
- The Assignment 4 image-scan remediation is committed, pushed, and cloud-accepted.
  Source-build CI build 7 at commit `e121f0a` completed `SUCCESS` with immutable tag
  `7-e121f0acc00d` and `DEPLOY_TO_EKS=false`. Bandit archived zero errors/findings,
  seven tests passed, and the blocking pipeline completed. Jenkins archived one
  digest and one Trivy report for each of frontend, backend, and worker; every
  exact digest scan reported zero HIGH and zero CRITICAL findings, and read-only
  Docker Hub inspection matched all three archived digests. The standalone CD
  count remained four, its stage was explicitly skipped, and all three healthy
  Deployments remained on accepted tag `2-192958c291ba`.
- Controlled failed-scan behavior is also cloud-accepted. CI build 10 used temporary
  commit `7001992` and tag `10-70019927c15e`; frontend/backend scans remained clean,
  while the intentionally vulnerable worker scan found six HIGH and zero CRITICAL
  findings and failed the pipeline. Post-stage cleanup deleted all three exact
  temporary Docker Hub tags, subsequent public checks returned 404 for each, S3 and
  standalone CD stages were skipped, CD remained at four builds, and all live
  Deployments remained 2/2 Ready on tag `2-192958c291ba`. The temporary local and
  remote evidence branch and generated cleanup-only recovery files were removed;
  Jenkins builds and screenshots were preserved.
- The final-stack data path is cloud-accepted. One explicitly approved synthetic
  request entered through public frontend route `/machines`, traversed the internal
  backend and worker Services, and returned HTTP 201 with record ID 2. The
  PostgreSQL-backed public catalog and AES256-encrypted, versioned S3
  `instances.json` contained the same record. The worker returns only after its
  synchronous SNS `Publish`; CloudWatch reported exactly one SNS message in the
  request window, no worker error signatures appeared, and all three Deployments
  remained 2/2 Ready.
- Final-stack self-healing is cloud-accepted. After one explicitly approved
  frontend Pod deletion, the owning ReplicaSet immediately created a replacement
  Pod with a different UID on the same immutable image. Sorted namespace events
  showed the stop, successful create, scheduling, pull, container creation, and
  start sequence. All three Deployments returned to 2/2 Ready and public `/`,
  `/health`, and `/machines` checks remained HTTP 200.
- The implementation enables EKS VPC CNI
  NetworkPolicy enforcement; adds default-deny-by-selection ingress/egress
  policies for frontend, backend, and worker; enables `RuntimeDefault` seccomp and
  read-only root filesystems with only required `emptyDir` mounts; and disables
  ServiceAccount token automount for frontend/backend while retaining the worker
  token for EKS Pod Identity. Root and Helm documentation now describe the
  Kubernetes boundary and layered NetworkPolicy/security-group/IAM controls.
- The custom CI agent now uses a digest-pinned Jenkins inbound-agent base. With
  explicit user approval, image
  `zer0w1/devops-project1-jenkins-agent:eks-python-v2` was published to
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
- Clone/fork reproducibility and the credential preflight fix are implemented.
  Setup detects and confirms a GitHub HTTPS repository and
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
  completed the full teardown.
- Local diagnostic hardening is complete: GitHub lifecycle
  failures use a shared secret-safe Ansible filter; Jenkins Python helpers share
  one classified client staged through a reusable ConfigMap task; webhook Groovy
  reports bounded credential/plugin categories; and backend HTTP errors no longer
  echo dependency exception text. Ten focused diagnostic tests, Python compilation,
  all affected playbook syntax checks, production-profile `ansible-lint`, Git
  whitespace checks, seven worker tests, Flake8, and Bandit pass. Terraform wrappers
  and both Jenkinsfiles required no diagnostic edits. The Jenkins CLI jar exists,
  but no local controller is running, so authoritative Declarative validation
  remains deferred to the next clean E2E.
- Resumed cloud acceptance exposed two final defects: successful Kaniko/CD work
  was marked CI failure when post-stage cleanup tried to exec into the exited
  Kaniko container, and create accepted ALB health without requiring the exact CI
  result. The implementation makes cleanup failure-safe and makes the in-cluster
  trigger follow its queue item and require the exact build to finish `SUCCESS`
  within a bounded ten-minute Job. The webhook-triggered CI build 5 passed, so the
  cleanup fix is cloud-accepted. A later from-zero run exercised the exact
  create-lifecycle result gate successfully after correcting optional empty image-
  tag handling; that run was intentionally not accepted as final evidence.
- The acceptance implementation also extracts the CI trigger,
  Jenkins job seeding, registry credential configuration, and webhook Groovy
  programs from oversized inline playbook blocks into project-owned helpers.
  Focused Python/shell compilation, four-playbook syntax checks, production lint,
  helper-reference inspection, and Git whitespace checks pass. A confirmation-
  gated login helper prints the private Jenkins credentials only to the operator
  terminal and is documented with terminal-scrollback precautions.
- The command-by-command E2E create/webhook/CI/CD/verification/teardown checklist
  has been reviewed. Jenkins is seeded against the remote acceptance branch.
- The final resumed acceptance stack used the
  source-built immutable images from CI build 12 and tag `12-6583917f0c6e`.
  Webhook CI build 13 completed `SUCCESS` with `DEPLOY_TO_EKS=false`; standalone
  CD build 7 deployed the worker writable-path correction. Frontend, backend,
  and worker reached 2/2 ready at Helm revision 6; `/`, `/health`, and `/machines`
  returned HTTP 200.
- The remediated images and Kubernetes hardening are cloud-accepted. The active
  VPC CNI add-on reports `enableNetworkPolicy=true`; each application release
  has an Ingress/Egress NetworkPolicy. All three Deployments use
  `RuntimeDefault` seccomp, read-only root filesystems, dropped capabilities, and
  no privilege escalation. Backend and worker run as UID/GID `10001`; frontend
  and backend disable ServiceAccount-token automount, while worker retains it for
  EKS Pod Identity. Required writable paths use bounded `emptyDir` volumes.
- The worker writable-path correction is cloud-accepted. One explicitly approved
  post-fix request returned HTTP 201 with record ID 3. The RDS-backed catalog read
  returned all three records; encrypted, versioned S3 `instances.json` contained
  the same third record; and the synchronous worker path returned only after its
  SNS `Publish` call completed. No worker error signatures appeared after the
  request.
- The approved normal teardown then completed without an application-data backup.
  An expired GitHub lifecycle token caused the first attempt to stop before any
  destructive stage; rerunning setup validated and encrypted a renewed token. The
  successful rerun removed the webhook and application objects, purged the
  dedicated cluster, destroyed all 77 Terraform-owned addresses, verified empty
  main state, and deleted the self-signed certificate. Read-only audit found no
  target EKS, RDS, application bucket, ALB, NAT gateway, VPC, or certificate. The
  external quick-demo bucket remains outside project ownership.
- A subsequent from-zero reproducibility attempt reached healthy source-built
  images tagged `2-890ad6889043`: CI build 2 and standalone CD build 1 completed
  `SUCCESS`, the exact create result gate passed, all three releases were 2/2 Ready
  at revision 1, public routes returned HTTP 200, and current hardening and
  NetworkPolicy controls were present. Two create-path defects discovered en route
  were fixed and pushed: create now stages backend initialization after fresh
  bootstrap, and the CI trigger accepts an intentionally empty optional image tag.
  Because the run required these interventions and had no common rollback target,
  it is diagnostic acceptance only; final evidence must be rerun from zero.
- The untracked `k8s/logging/` directory is unrelated class-lab work; preserve it
  untouched and exclude it from Assignment 4 commits and acceptance reasoning.
- During current acceptance work, Jenkins intentionally watches only
  `aws4-jenkins-cicd` while `main` carries the default-branch scheduled workflow
  without triggering project CI. After acceptance is complete, change the seeded
  Jenkins CI/CD SCM refs and related target-branch defaults from
  `aws4-jenkins-cicd` to `main`, then validate that intentional `main` pushes are
  the production CI trigger.

## Immediate work queue

1. Preserve the active final-evidence stack for the imminent project defense; do
   not run teardown beforehand.
2. Finish the documentation/evidence pass. After the defense, review teardown as a
   separate, explicitly authorized operation.

## Exact resume point

Resume on branch `aws4-jenkins-cicd` with the active final-evidence stack in account
`058264247987`, region `us-east-1`. Terraform main state in
`/home/geeta/Project1` owns 77 addresses, and its handed-off generated lifecycle
artifacts are authoritative. The source checkout includes the reviewed
documentation/evidence checkpoint based on `e121f0a`; the retained clean checkout
is at `7a8731b`. Jenkins CI build 7 from
`e121f0a` is the accepted source-build/no-CD image-scan evidence: tag
`7-e121f0acc00d`, three registry-matched immutable digests, and zero HIGH/CRITICAL
findings for all three images. CD remained at four builds and the live frontend,
backend, and worker remain 2/2 Ready on tag `2-192958c291ba`.
Controlled CI build 10 is the accepted failed-scan/registry-cleanup evidence; all
six temporary tags left by builds 8 and 10 are absent. The temporary evidence
branch is absent locally and remotely. The lifecycle checkout is back on
`aws4-jenkins-cicd` at its intentionally tracked-clean `7a8731b` fallback commit;
do not modify or fast-forward it until after the defense.
Final-stack record ID 2 is the accepted RDS/S3/SNS data-path evidence.
The approved frontend Pod deletion is accepted self-healing evidence; its
replacement reached Ready on the unchanged image and all public checks passed.
The protected historical `scripts/recreate_state_bucket_boundary.sh` targets
retired ownership and must not be rerun.
Preserve untracked `k8s/logging/` and `scripts/recreate_state_bucket_boundary.sh`.
Also preserve temporary evidence inventory/screenshots unless the user approves
their exact cleanup. The user explicitly requires the active stack to remain intact
for the imminent project defense. Continue lifecycle/state operations only from
`/home/geeta/Project1`; keep `/home/geeta/Project1-e2e-clean` as an untouched
fallback to avoid concurrent operators. Teardown is deferred until separately
authorized after the defense.

## Status-file maintenance rule

Keep this file short. At the end of a work session:

- update only current truth, active blockers, immediate work, and the resume
  point;
- remove or replace superseded current-state statements;
- move completed milestones, dated evidence, old inventories, and historical
  implementation detail to `misc/recovery/PROJECT_HISTORY.md`;
- do not accumulate chronological logs here.
