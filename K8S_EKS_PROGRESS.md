# Kubernetes / EKS Assignment Progress

Concise recovery note for the next session. Full recovered history is preserved in
`K8S_EKS_PROGRESS.md.full-backup-20260730T234556Z`.

## Working rules

- Edit one workspace file per patch/tool call.
- Run only short, single-line terminal commands directly.
- For longer Python, shell, AWS, Terraform, or diagnostic logic, first create a
  readable script file through the integrated editor, then invoke it with a
  short command such as `python3 scripts/.task_check.py`.
- Do not paste heredocs, inline Python, or compound multi-line shell programs
  into terminal execution requests.
- The assignment PDF, `DevOps_on_AWS_-_-_k8s__Docker.pdf`, is in the project
  root. Read/extract it before making implementation or final-compliance
  decisions; do not rely only on this recovery note for assignment requirements.
- High-volume output and normal long-running script files worked. A silent,
  long-running command may return an explicit fallback saying output was not
  captured despite successful execution; treat that as completed execution,
  but do not assume output is available.
- Never assume `localhost:8080` is EKS Jenkins. Verify the owning process and
  Jenkins response headers; use `18080` for an EKS controller port-forward.

## Verified AWS state — `us-east-1`, 2026-07-30

- No active EKS clusters, non-terminated EC2 instances, active NAT gateways,
  or allocated Elastic IPs.
- No RDS, ELB/ALB/NLB, ECS, ECR, Lambda, EFS, FSx, VPC endpoints, DynamoDB,
  ElastiCache, OpenSearch, Redshift, or owned EBS snapshots were found in the
  final inventory.
- S3 bucket `quick-demo-058264247987-us-east-1-an` exists and is explicitly
  out of scope: **do not alter it**.
- Four user-approved unattached EBS volumes were deleted and individually
  verified absent: `vol-09628b7392b379ed1`, `vol-00c19c0672838004f`,
  `vol-0199765fefda92c48`, and `vol-00224ea73bd71c0b0` (former Jenkins PVC).
  Total removed capacity: **53 GiB**.
- `eksctl-learn-eks-cluster` CloudFormation stack remains `CREATE_COMPLETE`
  with termination protection. Its NAT/EIP are gone. Do not delete the stack
  without explicit approval; it can retain VPC, subnet, route, security-group,
  and IAM resources.

## Architecture direction

- Services: frontend, backend, worker; external dependencies: RDS PostgreSQL,
  S3, SNS, and secrets handling.
- Docker builds images; Helm deploys them via `helm/frontend`, `helm/backend`,
  and `helm/worker`.
- Terraform should own AWS infrastructure, including future EKS.
- Ansible should become the official lifecycle orchestrator: Terraform apply →
  kubeconfig → Kubernetes secrets → Helm deploy → intentional teardown.
- Future EKS target: private nodes with NAT; recreating EKS/NAT incurs cost and
  requires explicit approval.
- Frontend currently uses temporary `LoadBalancer`; revisit ingress only after
  controller and cost requirements are decided.

## Jenkins status

### Current Jenkins-on-EKS lab — 2026-08-03

- An EKS Jenkins lab is currently active (this supersedes the historical
  2026-07-30 inventory statement below). Jenkins is privately accessed with:
  `kubectl -n jenkins port-forward svc/jenkins 18080:8080`. Occasional
  `broken pipe` / `connection reset` messages are normal client disconnects
  while the port-forward remains active.
- Job `devops-project1-eks-pipeline` is sourced from `Jenkins/Jenkinsfile.eks`.
  Its build Pod uses a Python agent, Helm, Trivy, and a Jenkins-compatible
  Kaniko image. Application deployment is opt-in and was disabled for the
  verified build.
- Added `Jenkins/Dockerfile.kaniko-agent`: a small compatibility layer over
  `gcr.io/kaniko-project/executor:v1.23.2-debug` that supplies the conventional
  `/bin/sh`, `cp`, `mv`, `touch`, and `nohup` paths Jenkins durable tasks need.
  Published image: `zer0w1/devops-project1-jenkins-kaniko-agent:eks-v2`
  (`sha256:04535c17ff326ea234bf722fe447bb46613a5595adb9eb2adf5587f1a930b1e4`).
- Kaniko runs as root only because image construction must preserve ownership
  metadata from `python:3.11-slim`. The Pod is still non-privileged with
  `allowPrivilegeEscalation: false`, `RuntimeDefault` seccomp, and only the
  Kaniko container receives `CHOWN`, `DAC_OVERRIDE`, and `FOWNER`; all other
  sidecars drop every Linux capability.
- Build #11 succeeded for `backend` with `DEPLOY_TO_EKS=false`. It completed
  checkout, Python/Bandit checks, Kaniko build/push, artifact archiving, and
  temporary Docker Hub auth cleanup. Published application image:
  `zer0w1/devops-project1-backend:11-068f0d1cc250` at
  `sha256:d091ba23865fcace28b4171f26f4998bddb3825b0d147bafdefdcb17edd2a691`.
- EKS Pod Identity Agent is active. Jenkins CD agents use ServiceAccount
  `jenkins/jenkins-deployer`, IAM role
  `arn:aws:iam::058264247987:role/devops-app-eks-jenkins-deployer`, an EKS
  access entry mapped to group `jenkins-deployer`, and namespace Role/Binding
  restricted to `devops-app`. A temporary verification Pod proved the expected
  STS assumed role, allowed Deployment/Secret actions, and denied Node deletion.
- Standalone CD job `devops-project1-eks-deploy` is sourced from
  `Jenkins/Jenkinsfile-deploy`. `scripts/create_jenkins_job.sh` now supports
  reusable pre-seeded string/boolean job parameters, and
  `scripts/create_jenkins_eks_deploy_job.sh` supplies all ten CD parameters so
  a fresh job exposes **Build with Parameters** before its first run.
- The standalone CD build succeeded on 2026-08-03 using immutable image
  `zer0w1/devops-project1-backend:11-068f0d1cc250`. Helm release
  `devops-app/backend` is revision 1 and `deployed`; both replicas are Ready
  with zero restarts, run as UID/GID 999, and the ClusterIP has two endpoints.
  A loopback port-forward returned
  `{"status":"ok","service":"backend-api"}` from `/health`.
- Runtime issues found and fixed during CD validation: cluster-scoped
  `kubectl cluster-info`/Namespace probes were replaced by namespaced
  Deployment reads to preserve least privilege; the image's named `USER app`
  was pinned to numeric UID/GID 999; and the Helm v4-incompatible
  `helm status --show-resources` flag was removed. Failed first-install attempts
  used `--atomic` and left no release/resources after rollback.
- The three-service implementation and CI/CD handoff fixes are committed and
  pushed through `b915d7ef25354e919240134f56dba3f257da865c` on
  `aws3-containerized`. The remaining dirty workspace includes unrelated and
  pre-existing Terraform, recovery, legacy Jenkins, and application work; do not
  stage it broadly.

### Three-service Jenkins pipeline direction — 2026-08-03

- `Jenkins/Jenkinsfile.eks` is the CI/orchestrator boundary: it checks the Python
  services, lints/templates all three Helm charts, builds and pushes frontend,
  backend, and worker with one immutable tag, and optionally triggers the
  standalone CD job.
- `Jenkins/Jenkinsfile-deploy` remains the only pipeline that changes application
  resources in EKS. It repeats Helm lint/template checks, deploys the worker,
  backend, and frontend releases with `--atomic`, and verifies all three images.
- PostgreSQL, S3 synchronization, and SNS notifications are intentionally
  disabled in the current Jenkins deployment. Terraform-derived worker values
  and Kubernetes DB Secret automation will be wired in a later infrastructure
  integration milestone rather than exposed as numerous build parameters now.
- Current job defaults are pre-seeded by thin wrappers
  `scripts/create_jenkins_eks_pipeline_job.sh` and
  `scripts/create_jenkins_eks_deploy_job.sh`; both delegate shared CLI/XML work
  to `scripts/create_jenkins_job.sh`.
- Temporary implementation: Helm command blocks remain in the Jenkinsfiles to
  focus first on proving all three services. Planned refactor: move deployment
  operations into a reusable helper/Jenkins Shared Library or invoke the
  `kubernetes.core.helm` Ansible module, leaving Jenkinsfiles as orchestration.
- The frontend nginx runtime template stays checked into the image build context
  for deterministic builds. Planned refactor: manage that nginx configuration
  through the frontend Helm chart ConfigMap and mount it into the Pod.

### Verified automatic CI → CD and final lab state — 2026-08-03

- Jenkins CI build **#17** built and pushed frontend, backend, and worker with
  shared immutable tag `17-b915d7ef2535`, then automatically triggered CD build
  **#13** with the repository, commit, image repositories, tag, namespace,
  cluster, and region handoff intact.
- CD deployed all three Helm releases successfully. Frontend, backend, and
  worker each reached **2/2 Ready** replicas (**6/6 total**) on the shared tag;
  all service endpoints were populated, the in-cluster frontend smoke test
  returned HTML, and the public frontend LoadBalancer returned **HTTP 200**.
- The undersized two-node `t3.small` node group was replaced safely with managed
  node group `app-medium-v1`: **3 × `t3.medium`**, minimum **3**, desired **3**,
  maximum **4**. Old nodes were cordoned/drained one at a time and their node
  group was deleted only after Jenkins, application, CoreDNS, metrics-server,
  and EBS CSI workloads were healthy on the replacement nodes.
- The complete local Terraform state currently contains **0 resources**. The
  active lab is shell/eksctl/Helm-managed; existing Terraform and the older
  `deploy_all_k8s.sh` flow are outdated and must not be treated as authoritative
  for creation or teardown until deliberately modernized/imported.
- Intentional dependency-ordered teardown is approved for tonight after this
  evidence is committed: application releases/LoadBalancer → Jenkins/PVC/EBS →
  Jenkins Pod Identity/access/IAM role → EKS cluster/node group → residual-cost
  audit. Preserve out-of-scope S3 bucket
  `quick-demo-058264247987-us-east-1-an`.

### Confirmed local Docker Jenkins work

- Job: `devops-project1-pipeline`, from `Jenkins/Jenkinsfile`.
- Default branch: `aws3-containerized`; default build: backend using
  `Dockerfile.backend` and `zer0w1/devops-project1-backend`.
- Worker/frontend require parameter changes.
- Verified through checkout, Python/security stages, Docker build, image
  inspection, and scan flow.
- SonarQube and Trivy are opt-in (`RUN_SONARQUBE=false`,
  `RUN_TRIVY_SCAN=false`). Docker Hub credentials and SMTP may need setup.
- Local Jenkins/SonarQube were stopped during memory troubleshooting; do not
  assume they are running.

### Jenkins-on-EKS status

- Current active cluster: `devops-app-eks` in `us-east-1`; three `t3.medium`
  worker nodes were Ready after the 2026-08-03 capacity migration. This incurs
  AWS cost until an intentional teardown is approved and completed.
- Active Jenkins and application state is documented in **Current
  Jenkins-on-EKS lab** above. The older 2026-07-30 no-cluster inventory is
  historical only and must not be used as current state.
- EKS/Jenkins assets include `Jenkins/values-eks.yaml`,
  `Jenkins/Jenkinsfile.eks`, `Jenkins/Jenkinsfile-deploy`,
  `Jenkins/rbac-app-deployer.yaml`, `scripts/deploy_jenkins_eks.sh`,
  `scripts/create_jenkins_eks_pipeline_job.sh`, and
  `scripts/create_jenkins_eks_deploy_job.sh`.

## Next session

1. Modernize Terraform and establish explicit infrastructure ownership. Update
   modules/state backend, define the desired EKS and supporting AWS resources,
   and use a deliberate import/recreation plan; never apply the current
   empty/outdated state against an existing environment.
2. Consolidate lifecycle automation around that ownership model. Replace the
   stale Terraform-dependent
   `deploy_all_k8s.sh` assumptions with one idempotent create workflow and one
   dependency-safe destroy workflow matching the proven three-node EKS/Jenkins
   architecture.
3. As part of the Terraform/lifecycle reimplementation, clean up and trim the
   codebase. Inventory files by domain and remove obsolete/redundant local Docker
   Jenkins flows, duplicate scripts, recovery artifacts, stale Helm assets, and
   abandoned application files only after confirming their purpose. Continue
   explicit-path staging; never use a broad `git add .` in the mixed workspace.
4. Refactor verbose Helm shell blocks from Jenkinsfiles into a reusable helper,
   Jenkins Shared Library, or Ansible `kubernetes.core.helm` workflow while
   retaining independent CI and CD jobs.
5. Re-read `DevOps_on_AWS_-_-_k8s__Docker.pdf` and update the primary README with
   concise architecture, reproducible setup, evidence, lifecycle, cost, and
   security instructions.