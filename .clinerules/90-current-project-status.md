# Current project status

Rolling recovery record for `/home/geeta/Project1`. Durable rules live in the
lower-numbered files in this directory. Full historical recovery text remains in
`/home/geeta/Project1/misc/recovery/K8S_EKS_PROGRESS.md.full-backup-20260730T234556Z`
as ignored local recovery material.

## Current safety and ownership boundary

- Terraform Phase 1 is a temporary local-only modernization gate. Do not run
  Terraform apply/import or mutate AWS while this boundary remains active.
- Local Terraform state last listed **0 resources**. The live environment named
  `devops-app-eks` was created through temporary shell/`eksctl`/CloudFormation
  flows; matching Terraform configuration does not establish ownership.
- A direct read-only parse of `terraform/terraform.tfstate` on **2026-08-08**
  reconfirmed **0 resource addresses**. Normal `terraform state list` now correctly
  requires explicitly approved backend reinitialization after the partial S3
  backend declaration; do not reinitialize or migrate merely to inspect the old
  local file.
- Never apply the empty state as implicit adoption. The transition to the intended
  Terraform-owned, Ansible-orchestrated lifecycle requires a reviewed
  import-versus-recreation plan and backend/state decision.
- Preserve external S3 bucket `quick-demo-058264247987-us-east-1-an`. Do not alter
  or silently adopt it; justify its role and ownership boundary in the README.
- Treat termination-protected CloudFormation stack
  `eksctl-learn-eks-cluster` as an external cleanup candidate. Its specific
  original purpose is unverified but is plausibly older learning/lab infrastructure;
  it is not a `devops-app-eks` dependency or Terraform-owned resource. Do not
  mutate or delete it during Phase 1.
- Read-only checks on **2026-08-08** found the stack `CREATE_COMPLETE` with a
  2026-06-15 creation time, while its recorded `learn-eks` control plane no longer
  exists. Its VPC/subnets/security groups are distinct from `devops-app-eks`, and
  its VPC had no active NAT gateway, VPC endpoint, load balancer, non-terminated
  instance, or RDS instance in the checked categories.
- Cloud observations below are dated evidence, not current truth. Reverify live
  state read-only before relying on it.
- The workspace contains substantial unrelated pre-existing tracked and untracked
  work. Preserve it, stage only explicit paths if later requested, and do not
  attribute all differences to the current task.

## Terraform Phase 1 completed milestones

- Root EKS module composition exists.
- Worker EKS Pod Identity association is owned at root.
- EKS public endpoint CIDRs are restricted to the approved admin CIDR; private
  endpoint access is enabled.
- Optional control-plane logging exists and defaults off.
- EKS input and node-scaling validations exist.
- Target configuration is Kubernetes **1.34** with three private `t3.medium`
  managed nodes: minimum/desired **3**, maximum **4**.
- EBS CSI uses IRSA; the worker uses EKS Pod Identity.
- VPC CNI permissions remain on the node role as a documented trade-off.
- Obsolete EC2 application security groups and compatibility outputs were removed.
- Root configuration allows EKS node security-group traffic to RDS PostgreSQL.
- One NAT gateway and one shared private route table remain a documented
  cost-versus-resilience trade-off.
- Terraform configuration last validated successfully and state last listed zero
  resources. No Terraform apply/import or AWS mutation occurred during Phase 1.
- `terraform/modules/networking/variables.tf` line endings were normalized and
  verified as ASCII text; recursive formatting and Terraform validation passed.
- The unused IAM-module copy of `db_password_secret_name` and its root module
  argument were removed. The active root variable, Secrets Manager resource, and
  root output remain intact.
- The main stack now declares a partial S3 backend with native
  `use_lockfile = true`. Environment-specific settings are generated outside Git.
- A separate validated `terraform/state-bootstrap` root defines the dedicated,
  versioned, encrypted, TLS-only, public-blocked Terraform-state bucket with
  bucket-owner enforcement and `prevent_destroy`. It owns no application data.
- `Ansible-modules-01/playbooks/configure_terraform_state.yml` now orchestrates
  provider-only validation plus separately gated state-bootstrap apply, main
  backend initialization/migration, and main apply. Phase 1 defaults all mutation
  stages off; a local run completed with `changed=0` and all mutation stages
  skipped. After the reviewed ownership migration, normal idempotent create-stage
  defaults should be revisited while migrations and destruction remain gated.
- The stale auto-applying `playbooks/apply_terraform.yml` wrapper was removed with
  explicit approval; `site.yml` references the guarded lifecycle directly.
- Terraform documentation now records the EKS target, automated state bootstrap,
  separate state/application buckets, empty-state/live-cluster boundary, and safe
  local validation workflow.
- Final local checks on **2026-08-08** passed for recursive main-stack formatting,
  main-stack validation, state-bootstrap formatting/validation, Ansible syntax, and
  the guarded Ansible execution (`ok=8`, `changed=0`, `skipped=8`). Git's whitespace
  check passed after normalizing the two remaining CRLF Terraform files. No backend
  initialization/migration, plan, apply/import, AWS/Kubernetes mutation, Git staging,
  commit, or push occurred.
- The root `K8S_EKS_PROGRESS.md` remains a compatibility pointer and now also holds
  a separate user action checklist for the pending professor consultation about the
  provisional Jenkins ALB versus SSM/bastion access decision.
- Local artifact organization on **2026-08-08** moved the assignment PDF to
  `misc/DevOps_on_AWS_-_-_k8s__Docker.pdf` and both retained progress backups to
  ignored `misc/recovery/`. The local Jenkins CLI jar remains retained and ignored.
  Six explicitly approved hidden one-off inventory/recovery helpers were removed;
  Jenkins assets and unclassified frontend files were preserved.
- The authoritative `Ansible-modules-01/playbooks/site.yml` no longer imports the
  obsolete EC2 inventory/nginx/systemd flow. It currently imports only the guarded
  Terraform lifecycle and the separately gated application-secret preparation
  stage. The transitional `deploy_k8s.yml` secret task that passed a Terraform
  secret name as the database password was removed.
- The selected database credential model is Terraform Secrets Manager source of
  truth -> explicitly gated Ansible synchronization -> namespace-scoped Kubernetes
  Secret -> worker `POSTGRES_PASSWORD`. Worker Pod Identity remains scoped to S3
  and SNS and does not fetch Secrets Manager values directly.
- `prepare_application_secret.yml` defaults `SYNC_APPLICATION_SECRET=false`, uses
  `no_log: true` around secret retrieval/application, and was not run in mutation
  mode. Syntax checks passed for that playbook, `site.yml`, and `deploy_k8s.yml`; a
  default `site.yml` run completed `ok=9`, `changed=0`, `skipped=12`. A focused Git
  whitespace check also passed. No AWS/Kubernetes/Helm mutation, Terraform plan,
  backend initialization/migration, apply/import, Git staging, commit, or push
  occurred during this work.
- Local environment/input automation was added on **2026-08-09**. The one-time
  `playbooks/setup_local_environment.yml` prompts only for administrator email,
  detects and confirms or overrides an IPv4 `/32`, derives the deterministic DB
  username from the committed prefix/environment, generates an ignored mode-0600
  `.vault-password`, and writes ignored mode-0600 Ansible-Vault-encrypted local
  variables. It was syntax-checked but not executed, so no network request or local
  private files were created during this work.
- `prepare_terraform_inputs.yml` is imported before Terraform lifecycle work and
  defaults `PREPARE_TERRAFORM_INPUTS=false`. When explicitly enabled after setup,
  it copies authoritative `terraform.tfvars.example` over ignored
  `terraform.tfvars`, replaces only email/CIDR/DB username under `no_log`, and runs
  read-only AWS STS caller-identity preflight. Its default run completed
  `ok=1`, `changed=0`, `skipped=8`; the enabled path was not run. Post-setup
  unattended decryption uses `ANSIBLE_VAULT_PASSWORD_FILE=.vault-password` rather
  than a global Ansible setting so clean-clone validation still works.
- The main Terraform root no longer reads the external `db_creds` secret. Explicit
  sensitive inputs now supply `admin_cidr`, `admin_email`, and `db_username`; stale
  data sources/locals/variable references were removed. The external live secret
  was not inspected, imported, changed, or deleted.
- RDS lifecycle choices are direct module invariants rather than single-value
  configuration knobs: encrypted `gp3`, private endpoint, zero backup retention,
  skip final snapshot, and deletion protection off. The Terraform-owned generated
  password secret retains `recovery_window_in_days=0` for the selected disposable
  stack boundary. The RDS and secret Terraform files were normalized to LF.
- The application S3 module was reverified locally with `force_destroy=false`,
  SSE-S3, full public-access blocking, bucket-owner enforcement, and a TLS-only
  policy. Versioning and noncurrent-version lifecycle were later removed because
  the selected recovery boundary optionally retains the two runtime objects locally
  before an intentional full teardown. No S3/AWS mutation ran.
- `terraform/README.md` now includes a three-tier direct Terraform recovery runbook:
  local diagnostics; reviewed backend/state recovery with backups; and explicitly
  approved emergency state/resource mutation followed by Ansible reconciliation.
  Ansible remains the routine create/destroy interface.
- Final local checks on **2026-08-09** passed Terraform recursive formatting,
  Terraform validation, focused stale-reference searches, S3 hardening searches,
  Git whitespace checks, syntax checks for setup/input/site playbooks, and a full
  default `site.yml` run (`ok=10`, `changed=0`, `skipped=20`). Validation reported
  only expected warnings from the stale ignored `terraform.tfvars`; it remains
  untouched until the user runs the encrypted setup and explicitly enabled input
  preparation. No plan, backend initialization/migration, apply/import/destroy,
  AWS/Kubernetes/Helm mutation, secret sync, Git staging, commit, or push occurred.
- A root `HANDIN_READINESS_CHECKLIST.md` now provides the human-readable path from
  this checkpoint to submission: remaining application integration, Helm/runtime,
  Jenkins, create/destroy lifecycle, approved cloud evidence, documentation, and
  cleanup work. It explicitly labels the repository as mid-refactor and not yet
  hand-in ready.
- A separate `playbooks/destroy.yml` now statically implements the selected fully
  disposable teardown for RDS/application S3/Jenkins PVC data while retaining the
  Terraform remote-state bucket. It defaults to local assertions/debug only and is
  never imported by `site.yml`. Its enabled path requires nonempty Terraform state
  with the expected EKS/RDS/S3 addresses, a kube context/API endpoint matching
  Terraform outputs, and exact cluster/application-bucket confirmation. It can
  optionally retain `index.html` and `instances.json` under ignored local
  `Ansible-modules-01/recovery/`, uses a narrow Helm/kubectl helper to remove
  application and Jenkins resources/PVC/namespaces, deletes those two S3 objects,
  then runs one Terraform main-stack destroy. Residual-cost inspection remains a
  separate optional read-only operational check, not part of destroy ownership.
- Destroy syntax, helper shell syntax, recursive Terraform formatting, Git
  whitespace, and the default destroy run passed on **2026-08-09**; the default run
  completed `ok=2`, `changed=0`, `skipped=15`. No Terraform remote-state access,
  AWS/Kubernetes/Helm mutation, destroy, Git staging, commit, or push occurred.
- The user approved the pipeline boundary on **2026-08-09**: CI is mandatory,
  successful CI does not require deployment, CD remains optional and separate, and
  only CD may mutate application workloads. The active pipeline paths remain
  `Jenkins/Jenkinsfile.eks` and `Jenkins/Jenkinsfile-deploy`; the professor-provided
  `helm/spring-music` chart is retained as a reference/template, not a production
  application release.
- The first redundancy cleanup batch removed the unused standalone EC2 Terraform
  module, obsolete EC2-oriented Ansible playbooks, and unused `helm/devops-app`
  umbrella metadata. Superseded direct Terraform/Helm scripts were moved under
  `scripts/legacy/`; the earlier local-Docker Jenkinsfile/helper were moved under
  explicit legacy paths and sanitized. Transitional `create_eks.sh`,
  `deploy_jenkins_eks.sh`, current EKS job helpers, separate application charts,
  imported roles, recovery material, and ignored Jenkins CLI jar were preserved.
- The canonical frontend source is now
  `Ansible-modules-01/roles/app/files/app/src/frontend/index.html`. Retained Jenkins
  controller/Python-agent build sources and plugin lock are now tracked project
  assets, and root/Ansible/Terraform/readiness documentation was reconciled to the
  current EKS architecture and safety boundary.
- Cleanup validation on **2026-08-09** passed shell syntax for retained/archived
  helpers, recursive Terraform formatting and main/bootstrap validation, `site.yml`
  and `destroy.yml` syntax/default runs (`ok=10`/`ok=2`, `changed=0`), Helm lint and
  render for all three application charts, Python compilation, documentation-link
  checks, focused stale-reference/private-value scans, and Git whitespace checks.
  No application tests exist yet. Only expected stale ignored-tfvars validation
  warnings remained. No cloud/network mutation, enabled secret sync, Terraform
  backend access/plan/apply/import/destroy, Git staging, commit, or push occurred.

## Current live EKS boundary — verified 2026-08-08

- Read-only checks found `devops-app-eks` **ACTIVE** in `us-east-1` at Kubernetes
  **1.34**. Its current node group `ng-1ca46650` is ACTIVE with three on-demand
  `t3.medium` AL2023 nodes, min/desired **3**, max **4**; all three nodes were Ready.
- This current cluster was recreated on **2026-08-06** through termination-protected
  CloudFormation stacks `eksctl-devops-app-eks-cluster` and
  `eksctl-devops-app-eks-nodegroup-ng-1ca46650`, both explicitly described by AWS
  as created/managed by `eksctl`. It remains outside Terraform state.
- The eksctl node group currently uses the two public subnets, whose
  `MapPublicIpOnLaunch` values are true. The EKS API has public access enabled for
  `0.0.0.0/0` and private access disabled. This is current transitional topology,
  not the desired Terraform topology of private nodes, private API access, and a
  restricted public CIDR.
- Active add-ons are EBS CSI, CoreDNS, Pod Identity Agent, kube-proxy,
  metrics-server, and VPC CNI. EBS CSI uses the transitional IRSA role
  `devops-app-eks-ebs-csi-controller-role`. The cluster currently has **zero** Pod
  Identity associations.
- Only Kubernetes system namespaces were present (`default`, `kube-system`,
  `kube-public`, and `kube-node-lease`). Jenkins and `devops-app` are not currently
  deployed. Therefore the 2026-08-03 Jenkins/application section below is
  historical evidence and must not be treated as current runtime state.
- Script classification from live, Git, and CloudFormation evidence:
  `scripts/deploy_all_k8s.sh` is stale (two `t3.small` defaults and no current app
  deployment); `scripts/apply_terraform.sh` is stale (claims EC2 root composition
  and assumes an initialized backend); `scripts/create_eks.sh` is transitional and
  partially matches live capacity/add-ons but remains an eksctl/public-topology
  owner; `scripts/deploy_jenkins_eks.sh` describes a historical lab flow. Preserve
  them until the redundancy inventory verifies their replacements.

## Historical Jenkins and application milestone — verified 2026-08-03

- The lab used EKS cluster `devops-app-eks` in `us-east-1` with managed node group
  `app-medium-v1`: three `t3.medium` nodes, min/desired 3 and max 4. This superseded
  the undersized two-node `t3.small` group after a cordon/drain migration.
- Jenkins was private behind ClusterIP and temporarily accessed by port-forward on
  local port `18080`; never assume `localhost:8080` is EKS Jenkins. Port-forwarding
  was a lab/bootstrap method, not the intended final day-to-day access path. The
  selected target is a separate AWS Load Balancer Controller-managed ALB Ingress:
  AWS scheme `internet-facing`, but HTTPS restricted to the approved admin CIDR,
  with TLS and Jenkins authentication mandatory. The Jenkins Service remains
  ClusterIP. This controlled administrative endpoint is distinct from the generally
  public application frontend; retain port-forward only as an authorized fallback.
- CI job `devops-project1-eks-pipeline` uses `Jenkins/Jenkinsfile.eks`. It checks
  all services/charts, builds frontend/backend/worker with one immutable tag, and
  may trigger CD.
- CD job `devops-project1-eks-deploy` uses `Jenkins/Jenkinsfile-deploy` and is the
  only pipeline boundary that changes application resources in EKS.
- CI build **#17** published all three services with tag `17-b915d7ef2535` and
  triggered CD build **#13**. CD deployed frontend, backend, and worker at **2/2
  Ready** each (**6/6 total**); endpoints were populated, in-cluster frontend smoke
  testing returned HTML, and the public frontend LoadBalancer returned HTTP 200.
- Earlier backend-only CI build **#11** published
  `zer0w1/devops-project1-backend:11-068f0d1cc250` at digest
  `sha256:d091ba23865fcace28b4171f26f4998bddb3825b0d147bafdefdcb17edd2a691`.
  Standalone CD deployed it successfully as backend release revision 1; both
  replicas were Ready and `/health` returned backend status JSON.
- EKS Pod Identity Agent was active. Jenkins agents used ServiceAccount
  `jenkins/jenkins-deployer`, IAM role
  `arn:aws:iam::058264247987:role/devops-app-eks-jenkins-deployer`, an EKS access
  entry/group, and namespace-scoped RBAC for `devops-app`. Verification allowed
  required Deployment/Secret actions and denied Node deletion.
- Custom Kaniko compatibility image
  `zer0w1/devops-project1-jenkins-kaniko-agent:eks-v2` has digest
  `sha256:04535c17ff326ea234bf722fe447bb46613a5595adb9eb2adf5587f1a930b1e4`.
  Kaniko ran as root only to preserve image ownership metadata; the Pod remained
  non-privileged with no privilege escalation, RuntimeDefault seccomp, and narrowly
  limited capabilities on only that container.
- CD validation fixed cluster-scoped probes that violated least privilege, pinned
  the image user to numeric UID/GID 999, and removed Helm v4-incompatible
  `--show-resources`. Atomic failed installs left no release/resources.
- Three-service CI/CD work was committed and pushed through
  `b915d7ef25354e919240134f56dba3f257da865c` on `aws3-containerized`; do not infer
  that remaining workspace differences belong to that milestone.
- PostgreSQL, S3 synchronization, and SNS notifications were intentionally disabled
  in that Jenkins deployment pending infrastructure integration.

## Historical AWS cleanup evidence — verified 2026-07-30

This inventory predates and is superseded by the 2026-08-03 EKS lab evidence. It
must not be treated as current cloud state.

- At that time there were no active EKS clusters, non-terminated EC2 instances,
  active NAT gateways, allocated Elastic IPs, RDS, ELB/ALB/NLB, ECS, ECR, Lambda,
  EFS, FSx, VPC endpoints, DynamoDB, ElastiCache, OpenSearch, Redshift, or owned
  EBS snapshots in the final inventory.
- Four approved unattached EBS volumes were deleted and individually verified
  absent: `vol-09628b7392b379ed1`, `vol-00c19c0672838004f`,
  `vol-0199765fefda92c48`, and `vol-00224ea73bd71c0b0` (former Jenkins PVC),
  totaling **53 GiB**.
- The protected `eksctl-learn-eks-cluster` stack remained `CREATE_COMPLETE`; its
  NAT/EIP were gone, but it could retain VPC, subnet, route, security-group, and
  IAM resources.

## Known temporary implementations and later work

- Current Jenkins deployment helpers are temporary and mix responsibilities;
  Terraform must own AWS identity/infrastructure while Ansible becomes the
  idempotent lifecycle orchestrator for Jenkins, job seeding, and application CD.
- The provisional Jenkins access target is the controlled ALB Ingress above, but
  pause implementation until the professor confirms whether its CIDR-restricted
  internet-facing scheme is acceptable or a private SSM/bastion path is expected.
  If retained, implement controller IAM, security-group CIDR restriction, TLS/DNS,
  Ansible lifecycle ordering, validation, cost, and teardown. No VPN is currently
  assumed in project scope.
- Helm command blocks remain verbose in Jenkinsfiles. Refactor toward Ansible
  `kubernetes.core.helm`, a reviewed helper, or a Shared Library without merging CI
  and CD boundaries.
- Frontend nginx runtime configuration remains inside the image build context;
  later move non-secret configuration into a Helm-managed ConfigMap.
- The frontend used a temporary public LoadBalancer. Revisit ingress only after
  controller, TLS, security, and cost requirements are decided.
- Local Docker Jenkins job `devops-project1-pipeline` exists but local Jenkins and
  SonarQube were stopped during memory troubleshooting; do not assume they run.
- Later cleanup must inventory purpose before removing duplicate scripts, stale
  Helm assets, recovery artifacts, local Jenkins flows, or abandoned application
  files. Do not modify imported Ansible roles.
- The primary README and architecture diagram still need assignment-complete
  architecture, build/publish, namespace/secrets, deployment, evidence, teardown,
  security, RDS/S3/SNS connectivity, manual steps, and trade-off documentation.

## Project completion backlog

The PDF distinguishes core requirements from bonus features. The groups below do
the same. “Chosen-project requirements” are not extra-credit claims; they are work
needed to make this repository's selected Terraform/Ansible/Jenkins/EKS design
coherent, reproducible, and safe.

### Core assignment requirements

- [ ] Complete local/static application-data integration for the required external
  PostgreSQL, S3, and SNS services: runtime configuration, Kubernetes Secret and
  ConfigMap wiring, database schema/error handling, `index.html` bootstrap,
  `instances.json` synchronization, notifications, and automated application tests.
- [ ] After a future explicitly approved deployment, verify PostgreSQL was created
  or connected as intended and collect non-secret evidence for reachability,
  TLS/authentication, schema creation, writes/reads, recataloguing, restart
  persistence, and denied access from unintended callers.
- [ ] Verify the worker treats PostgreSQL as the primary structured datastore,
  writes the synchronized backup to S3 object `instances.json`, and emits the
  intended SNS notifications without exposing credentials or machine records.
- [ ] Finish required Kubernetes runtime configuration: all three services as
  Deployments/Services in the application namespace, internal-only backend/worker,
  ConfigMaps, Secrets, probes/resources/security contexts, and documented network
  paths to RDS, S3, and SNS.
- [ ] Decide and implement the required external frontend entry point; document
  its public/private trust boundary and keep backend, worker, RDS, S3, and SNS
  non-public. Treat the selected CIDR-restricted Jenkins ALB as a separate controlled
  administrative endpoint, not as the generally public application entry point.
  TLS, WAF, and advanced application-ingress controls are bonus items below.
- [ ] Produce the assignment-complete README and architecture diagram covering
  images, Kubernetes resources, external services, configuration/secrets, network
  flow, deployment, verification, recovery, security, and required evidence. It
  must justify the Jenkins ALB's internet-facing AWS scheme, approved-CIDR HTTPS
  restriction, TLS/authentication, ClusterIP backend, no-VPN scope, cost, fallback,
  and teardown.
- [ ] After a future explicitly approved deployment, collect non-secret submission
  evidence for nodes, namespaces, workloads, Services/entry point, pod details and
  logs, frontend access, service-to-service flow, RDS reads/writes, S3 objects, SNS
  behavior, scaling, and restart/self-healing.

### Chosen-project requirements and safety work

- [ ] Complete the local Terraform Phase 1 gate: normalize/validate configuration,
  remove verified-unused inputs, harden modules, define the partial S3 backend,
  inspect only allow-listed non-secret inputs, and update ownership documentation.
- [ ] Decide and document the Terraform state/backend transition and the
  import-versus-recreation boundary resource by resource; preserve state backups
  and never use empty state as implicit adoption.
- [ ] Complete local/static validation of Terraform-owned RDS PostgreSQL: module
  wiring, private subnet placement, node-to-database security-group path, secret
  flow, outputs, worker configuration, schema initialization, and failure handling.
- [ ] Create a new private Terraform-owned application-content S3 bucket, upload
  the initial `index.html` through Ansible after Terraform outputs exist,
  and remove runtime dependence on the legacy `quick-demo-058264247987-us-east-1-an`
  bucket without altering that legacy bucket.
- [ ] Implement and statically validate one idempotent Ansible create workflow:
  Terraform infrastructure; kubeconfig/prerequisites; Jenkins namespace, storage,
  Helm release, identity/RBAC and job seeding; initial S3 content; application
  secrets/configuration; then deployment through the standalone CD job.
- [x] Implement and statically validate a separate dependency-ordered Ansible
  destroy workflow covering application entry points/releases, Jenkins state,
  EKS/infrastructure teardown, and retained-data decisions; never make destroy an
  implicit deploy action.
- [ ] Execute and verify the reviewed teardown only with explicit approval, then
  audit AWS for residual billable resources and document intentionally retained
  data/external resources without mutating the legacy bucket or old protected stack
  outside their separately approved cleanup decisions.
- [x] Inventory redundancy by domain before cleanup: temporary shell/`eksctl`
  lifecycle scripts, duplicate Jenkins flows, stale Helm charts/assets, recovery
  artifacts, old EC2 application paths, and abandoned application files.
- [x] Remove or archive the first approved batch whose ownership and replacement
  were verified; continue preserving transitional helpers until replacement
  coverage exists, imported Ansible roles, unrelated work, evidence still
  needed for submission, and recovery material still serving a purpose.
- [ ] Re-run domain tests, documentation links, and lifecycle validation after each
  cleanup batch so trimming does not create a second ownership path or break CI/CD.

### Explicit PDF bonus features selected by this project

These improve the submission but are not prerequisites for satisfying the PDF's
core requirements. Do not present unimplemented bonus ideas as completed work.

- [ ] Finish and document the selected full-Helm implementation, including the
  frontend nginx ConfigMap and immutable environment-specific values.
- [ ] Complete the selected per-Deployment ServiceAccount and EKS workload-identity
  bonus: worker Pod Identity, EBS CSI IRSA, least-privilege permissions, and denied
  unauthorized-access evidence.
- [ ] Refactor and revalidate the selected Jenkins CI/CD bonus while preserving
  independent CI and CD jobs, one immutable image tag, CD-only application
  mutation, atomic deployment/rollback, and least-privilege agents.
- [ ] Run and document selected image scanning (for example Trivy) with an explicit
  inherited-vulnerability policy; scanning is bonus and must not be confused with
  the required container/image documentation.
- [ ] Decide separately whether to implement additional PDF bonuses such as TLS/
  ACM/cert-manager/WAF, NetworkPolicies, HPA, PodDisruptionBudgets, GitOps, or
  Prometheus/Grafana and CloudWatch/Loki. These are optional and not current core
  completion blockers.

## Exact Terraform Phase 1 resume point

1. Local input, RDS, S3, and recovery-runbook refactoring is complete and validated.
   The user has not run `setup_local_environment.yml`; therefore `.vault-password`
   and encrypted `vault/local-environment.yml` do not yet exist, and the ignored
   effective `terraform.tfvars` remains stale. Do not inspect it broadly. The user
   may run setup interactively, then explicitly enable input preparation with
   `PREPARE_TERRAFORM_INPUTS=true` and
   `ANSIBLE_VAULT_PASSWORD_FILE=.vault-password`; that stage rewrites only the
   ignored tfvars and performs read-only AWS STS preflight, not Terraform apply.
2. Deliberate parallel recreation remains selected instead of import. The future
   Terraform EKS cluster must use a distinct name from the externally owned live
   eksctl cluster. No plan, backend transition, apply, import, destroy, or cloud
   mutation is authorized; review effective inputs, costs, reads, and the fresh
   state/backend boundary before requesting any such action.
3. Continue the guarded Ansible create workflow after infrastructure: kubeconfig
   and cluster prerequisites; Jenkins namespace/storage/Helm/identity/RBAC/job
   seeding; initial repository `index.html` upload to the Terraform-owned bucket;
   application secrets/configuration; then standalone CD invocation. Keep Terraform
   as AWS owner and Ansible as routine lifecycle orchestrator.
4. The dependency-ordered destroy workflow is now statically validated. Do not run
   its enabled path until the Terraform-owned stack has been created and verified;
   retain transitional teardown scripts until replacement coverage is demonstrated.
   Residual-cost inspection remains a separate optional read-only operation.
5. Continue local worker/PostgreSQL/S3/SNS integration and tests, then guarded
   Ansible create lifecycle and Helm/CD wiring. The root README now reflects the
   target architecture but still requires assignment-complete deployment,
   verification, recovery, cost, and evidence sections after implementation. Do
   not modify imported Ansible roles, the legacy external S3 bucket, the protected
   old stack, or unrelated workspace files; do not push without a request.