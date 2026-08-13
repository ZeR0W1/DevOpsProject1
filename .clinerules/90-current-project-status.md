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

- The supported lifecycle is `bash setup.sh`, then
  `Ansible-modules-01/playbooks/create.yml`; teardown is the separate default-off
  `playbooks/destroy.yml`. Ansible commands run from `Ansible-modules-01` with its
  single `ansible.cfg`.
- The clean option-2 `BUILD_AND_DEPLOY` acceptance completed end to end after the
  Ansible vault-ID and cross-play fact-namespace fixes. Retained state discovery,
  all Terraform resources, private Jenkins, registry synchronization, separate CI
  and FULL CD, application delivery, and teardown were exercised in order.
- CI built and published frontend, backend, and worker with one immutable tag;
  standalone FULL CD deployed two Ready replicas of each service. The frontend
  LoadBalancer was the only public endpoint; backend, worker, and Jenkins remained
  ClusterIP-only.
- Acceptance verified nodes/namespaces/workloads/Services, no-Ingress design, pod
  description/logs, public HTTP, frontend-to-backend communication, PostgreSQL
  write/read persistence, versioned S3 `instances.json`, metadata-only SNS, and
  continued operation after one approved worker Pod replacement.
- Worker PostgreSQL uses TLS `require`; packaging or mounting the AWS RDS CA bundle
  for `verify-full` remains an optional future hardening item.
- Project-facing documentation is project-focused and split across the root,
  Ansible, Terraform, Jenkins, and service READMEs. Root documentation includes
  workstation bootstrap, single-branch clone, AWS credential scope, architecture,
  reproduction, verification/evidence links, security, teardown, and trade-offs.
- `p3_evidence/` contains 17 non-secret screenshots and is currently untracked.
  `HANDIN_READINESS_CHECKLIST.md` remains local, ignored, and removed from the Git
  index. No commit or push has been performed for this documentation/evidence pass.
- Final local checks passed for Python compilation, Ansible create/site/destroy
  syntax, all Helm lint/renders, both Terraform validations plus recursive format,
  shell syntax, Markdown links, evidence integrity, Git whitespace, ignored private
  paths, and scoped secret patterns. Worker tests passed locally (`7 passed`) in an
  isolated ignored service `.venv`. Both service and controller dependency checks
  are clean; the root controller environment retains its accepted AWS CLI `1.45.9`
  and boto3/botocore `1.43.9` pins.

## Immediate work queue

1. Review the documentation/evidence diff with the user.
2. Commit and push only if the user explicitly requests those actions.
3. Optionally harden PostgreSQL to `verify-full` in a future rebuilt worker image.

## Exact resume point

Resume with user review of the current documentation/evidence diff. Do not rerun
cloud acceptance unless requirements or relevant external state change. Main
Terraform state is empty, the target billable-resource audit is clean, and only the
retained state bucket remains. Preserve PostgreSQL-primary storage, fixed
`instances.json`, metadata-only SNS, versioned `index.html`, separate Pod
Identities, CD-owned frontend content, and Kubernetes Secret boundaries. Do not
commit or push without an explicit user request.

## Status-file maintenance rule

Keep this file short. At the end of a work session:

- update only current truth, active blockers, immediate work, and the resume
  point;
- remove or replace superseded current-state statements;
- move completed milestones, dated evidence, old inventories, and historical
  implementation detail to `misc/recovery/PROJECT_HISTORY.md`;
- do not accumulate chronological logs here.
