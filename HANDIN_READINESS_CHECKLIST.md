# Hand-in readiness checklist

This is the human-readable completion list for the DevOps on AWS assignment.
Items marked complete have local/static evidence in the repository. Cloud actions
must remain explicitly approved, cost-aware, and dependency-ordered.

## 1. Safety and ownership decisions

- [x] Keep Terraform as the owner of AWS infrastructure.
- [x] Keep Ansible as the normal create/destroy lifecycle orchestrator.
- [x] Keep Jenkins CI and CD as separate jobs; only CD changes application workloads.
- [x] Use deliberate parallel recreation instead of importing the live eksctl stack.
- [x] Give the future Terraform EKS cluster a distinct name.
- [x] Preserve the legacy application S3 bucket and protected old CloudFormation stack.
- [x] Retain the Terraform state bucket by default during main-stack teardown.
- [x] Treat RDS data, application S3 data, and Jenkins PVC data as disposable on an
  explicitly approved full teardown.
- [ ] Review the final account, region, cluster name, state/backend boundary, costs,
  and teardown plan before authorizing any Terraform plan or cloud mutation.

## 2. Local environment and Terraform inputs

- [x] Commit a non-secret authoritative `terraform.tfvars.example`.
- [x] Add one-time interactive setup for administrator email and confirmed `/32`.
- [x] Derive a deterministic PostgreSQL administrator username.
- [x] Store private local inputs in an ignored Ansible-Vault-encrypted file.
- [x] Keep AWS credentials and the generated database password out of local vars.
- [x] Add gated regeneration of ignored `terraform.tfvars` plus read-only AWS STS
  identity preflight.
- [ ] Run the one-time setup locally when ready.
- [ ] Review the generated non-secret effective settings without exposing private
  values, then explicitly run the gated input-preparation stage.

## 3. Terraform infrastructure

- [x] Define VPC networking, private EKS nodes, EKS 1.34, and 3/3/4 `t3.medium`
  managed-node scaling.
- [x] Restrict EKS public API access to the administrator `/32` and enable private
  endpoint access in the target configuration.
- [x] Configure EBS CSI IRSA and worker EKS Pod Identity.
- [x] Define private RDS PostgreSQL and the EKS-node-to-database network path.
- [x] Configure disposable RDS lifecycle: encrypted `gp3`, no public endpoint,
  backup retention 0, no final snapshot, and deletion protection off.
- [x] Remove the main stack's runtime dependency on the external `db_creds` secret.
- [x] Define a private, versioned, encrypted, TLS-only application S3 bucket with
  public access blocked and bucket-owner enforcement.
- [x] Define a separate hardened Terraform-state bootstrap root and partial S3
  backend with native lock files.
- [x] Document direct Terraform diagnostics and emergency recovery tiers.
- [ ] Review a fresh-stack plan only after effective inputs, backend ownership,
  provider reads, costs, and the distinct cluster name are approved.
- [ ] Apply only through the explicitly approved Ansible lifecycle.

## 4. Application data integration

- [ ] Make PostgreSQL the worker's primary structured datastore.
- [ ] Add idempotent schema initialization and useful database failure handling.
- [ ] Load initial `index.html` from the checked-out repository on every create.
- [ ] Synchronize the machine catalog to S3 object `instances.json`.
- [ ] Publish the required SNS notifications without leaking machine records or
  credentials.
- [ ] Add automated tests for database schema, writes/reads, S3 synchronization,
  SNS calls, disabled integrations, and failure paths.

## 5. Kubernetes and Helm

- [ ] Finish frontend, backend, and worker Deployments and Services in `devops-app`.
- [ ] Keep backend and worker internal; expose only the application frontend.
- [ ] Finish ConfigMap and Secret wiring for RDS, S3, SNS, and service endpoints.
- [ ] Verify resource requests/limits, probes, immutable tags, labels/selectors,
  ServiceAccounts, and least-privilege security contexts for all three services.
- [ ] Move frontend nginx runtime configuration into a Helm-managed ConfigMap.
- [ ] Decide and implement the final public frontend entry point.
- [ ] Re-lint and template every chart with production-intended values.

## 6. Jenkins and CI/CD

- [x] Keep independent three-service CI and standalone CD pipelines.
- [x] Build frontend, backend, and worker with one immutable image tag.
- [x] Keep application mutation inside CD and use atomic Helm deployment behavior.
- [ ] Move Jenkins AWS identity/infrastructure ownership into Terraform.
- [ ] Implement idempotent Ansible Jenkins namespace, storage, Helm, RBAC, identity,
  and job-seeding stages.
- [ ] Resolve the professor decision for CIDR-restricted Jenkins ALB versus a private
  SSM/bastion access path.
- [ ] If the Jenkins ALB is retained, add TLS, administrator-CIDR restriction,
  authentication, lifecycle ordering, cost notes, and teardown coverage.
- [ ] Refactor verbose reusable Helm operations without merging CI and CD boundaries.
- [ ] Run the selected image scanning step and document the inherited-vulnerability
  policy if this bonus is retained.

## 7. Create and destroy automation

- [ ] Complete the Ansible create order: inputs/state -> Terraform infrastructure ->
  kubeconfig/prerequisites -> Jenkins -> initial S3 content -> application config -> CD.
- [ ] Implement a separate destroy playbook; never import destroy into `site.yml`.
- [ ] Require exact account/region/cluster/backend/state confirmations before destroy.
- [ ] Destroy application entry points and Helm releases before cluster infrastructure.
- [ ] Remove Jenkins release, PVC, RBAC, and owned identity resources in order.
- [ ] Empty all versions/delete markers from only the Terraform-owned application
  bucket before destroying it; never target the legacy external bucket.
- [ ] Destroy the Terraform-owned main stack while retaining the state bucket.
- [ ] Finish with a read-only residual billable-resource audit.
- [ ] Keep transitional scripts until the Ansible workflows demonstrably replace them.

## 8. Approved future cloud verification and evidence

- [ ] Verify AWS identity and kubeconfig context before every approved mutation.
- [ ] Capture non-secret evidence for EKS nodes, namespaces, workloads, Services,
  entry points, pod details, logs, scaling, and self-healing.
- [ ] Verify frontend external access and frontend-to-backend communication.
- [ ] Verify private RDS TLS/authentication, schema creation, writes/reads, restart
  persistence, and denied access from unintended callers.
- [ ] Verify `instances.json` synchronization and expected SNS notifications.
- [ ] Verify least-privilege permissions and denied unauthorized actions.
- [ ] Execute the reviewed teardown and audit intentionally retained resources and
  any residual costs.

## 9. Documentation and submission cleanup

- [ ] Finish the root README with architecture, prerequisites, build/publish,
  configuration, secrets, create, verification, recovery, destroy, security, costs,
  trust boundaries, and trade-offs.
- [ ] Add an assignment-complete architecture diagram showing AWS, VPC/subnets,
  EKS namespaces/workloads/services, Jenkins, RDS, S3, SNS, identities, and traffic.
- [ ] Clearly distinguish the public application endpoint from the controlled Jenkins
  administrative endpoint.
- [ ] Document why the legacy bucket and protected old stack remain externally owned.
- [ ] Inventory duplicate scripts, old EC2 paths, Helm assets, Jenkins flows, and
  abandoned frontend files before requesting any deletion.
- [ ] Remove/archive redundant files only with explicit approval and after validating
  their replacements.
- [ ] Run all local tests, Terraform/Ansible/Helm validation, documentation-link
  checks, Git whitespace checks, and a final secret scan.
- [ ] Review the final staged diff, ensure no private/ignored artifacts are included,
  then create the final hand-in commit and push only when explicitly requested.

## Current checkpoint warning

The current repository checkpoint is **mid-refactor**. Local static validation has
passed for the completed Terraform/Ansible slice, but the new end-to-end lifecycle,
application integrations, destroy workflow, and final target cloud deployment have
not been executed or proven. Do not represent this checkpoint as hand-in ready.