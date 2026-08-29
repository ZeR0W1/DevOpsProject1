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
  `us-east-1`, was destroyed successfully after the completed final acceptance
  run. Main remote state is empty.
- The post-destroy read-only audit found no target EKS cluster, RDS instance, NAT
  gateway, load balancer, or application-data bucket. The separate versioned,
  encrypted remote-state bucket remains intentionally retained.
- The live `devops-app-eks` environment remains externally owned by
  `eksctl`/CloudFormation and outside Terraform state. It is a lecture-lab cluster
  containing only a Jenkins controller/plugins setup; disregard it when reasoning
  about target project architecture and do not mutate it for project work.
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
  Assignment 3 commit `db8f9f7`. The implementation is locally validated and is
  recorded in one user-approved local commit. That checkpoint was explicitly
  pushed as a fast-forward to default branch `main` so the scheduled GitHub CIDR
  workflow is available; the Jenkins-watched `aws4-jenkins-cicd` branch was not
  pushed, and no cloud mutation occurred.
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
- Main Terraform apply failures now stop the lifecycle before EKS/Jenkins and
  application stages, preserve remote-state progress, report only state-owned
  addresses, and direct the operator to resolve the smallest reviewed conflict or
  provider issue before rerunning the idempotent create lifecycle. No automatic
  import, delete, rename, retry, or rollback occurs.
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

1. Complete and verify the authorized Assignment 4 hardening commit and push of
   only the `aws4-jenkins-cicd` acceptance branch.
2. Run the reviewed E2E acceptance gates only with stage-specific approval.
3. After acceptance, switch the Jenkins-watched branch and related defaults to
   `main` and validate the resulting trigger behavior.

## Exact resume point

Resume on local branch `aws4-jenkins-cicd` by completing and verifying the
explicitly authorized hardening commit/push boundary, then stop before the
read-only acceptance precheck unless the user continues. Preserve untracked
`k8s/logging/` class-lab files. Do not run Terraform plan/apply, backend
reinitialization, cloud acceptance, another commit, push, domain registration,
or other cloud/GitHub mutation without explicit user approval.

## Status-file maintenance rule

Keep this file short. At the end of a work session:

- update only current truth, active blockers, immediate work, and the resume
  point;
- remove or replace superseded current-state statements;
- move completed milestones, dated evidence, old inventories, and historical
  implementation detail to `misc/recovery/PROJECT_HISTORY.md`;
- do not accumulate chronological logs here.
