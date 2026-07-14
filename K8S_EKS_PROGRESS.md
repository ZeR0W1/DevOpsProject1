# Kubernetes / EKS Assignment Progress Context

This file is a recovery and continuity note for future Cline sessions. It summarizes the previous Cline conversation, the current restructuring, what has already been changed, and what is planned next.

## Source of recovered context

- Previous Cline task storage inspected safely from:
  - `/home/geeta/.vscode-server/data/User/globalStorage/saoudrizwan.claude-dev/tasks/1783609704851`
- Main files found there:
  - `ui_messages.json`
  - `api_conversation_history.json`
  - `focus_chain_taskid_1783609704851.md`
  - `task_metadata.json`
- The previous task eventually got stuck in an automated tool-use error loop after the user asked:
  > don't we want the terraform stuff to be in the respective script?

## Important working rules from the conversation

- Make file edits one file at a time.
- Explain concepts in chat, not as excessive comments in files.
- File comments should document intent, placeholders, or operational details, not replace study explanations.
- When checking remote Docker image manifests, run checks one by one to avoid hanging/unclear output.

## Assignment direction

The assignment is to move the previous EC2-based three-service application into Kubernetes/EKS:

- frontend service
- backend service
- worker service
- external AWS dependencies remain relevant:
  - RDS PostgreSQL
  - S3
  - SNS
  - credentials/secrets handling

The chosen practical direction evolved as follows:

1. Initially target AWS EKS.
2. Use the existing EKS cluster temporarily.
3. Later, the existing EKS cluster was deleted because it was costing money.
4. Current recommendation: use shell scripts for now to sequence Terraform, EKS creation, and Helm deployment.
5. AWS-side idle cleanup was discussed as desirable later, but not implemented yet.

## Architecture decisions made

- Dockerfiles are required because Helm does not build the app; Helm deploys already-built container images.
- Helm is responsible for Kubernetes resources and deployments.
- The app is split into separate microservice Helm charts because the assignment/teacher expects each service to have its own chart and values file:
  - `helm/frontend`
  - `helm/backend`
  - `helm/worker`
- The older `helm/devops-app` chart exists but is not the main direction for the current microservice-chart workflow.
- Frontend HTML should remain a real file in the repo and be loaded into a ConfigMap, rather than embedding large HTML in `values.yaml`.
- Updating frontend HTML can be handled by syncing the HTML file before `helm upgrade`.
- `deploy_k8s.sh` currently performs the Helm deployment flow and consumes Terraform outputs.
- Terraform should remain responsible for AWS app infrastructure outputs such as RDS/S3/SNS values.
- EKS cluster creation is currently script-managed, not Terraform-managed.
- Frontend exposure is still an explicit pending decision:
  - option A: Kubernetes `Ingress` in front of the frontend Service, likely with an AWS Load Balancer Controller or nginx ingress controller;
  - option B: frontend Service of type `LoadBalancer`;
  - option C: keep `ClusterIP` internally while using another already-installed ingress path.
  - Current chart contains an ingress template, but the final exposure method should be verified against the actual EKS cluster add-ons and assignment expectations before final submission.

## Completed changes from the previous task and current task

- [x] Added/updated Docker-related app assets for containerized deployment.
- [x] Added Dockerfiles for app services:
  - `Ansible-modules-01/roles/app/files/app/Dockerfile.frontend`
  - `Ansible-modules-01/roles/app/files/app/Dockerfile.backend`
  - `Ansible-modules-01/roles/app/files/app/Dockerfile.worker`
- [x] Added frontend nginx container config:
  - `Ansible-modules-01/roles/app/files/app/src/frontend/nginx/default.conf.template`
- [x] Added/updated separate Helm charts and values for services:
  - `helm/frontend`
  - `helm/backend`
  - `helm/worker`
- [x] Added frontend chart file-based HTML support:
  - `helm/frontend/files/index.html`
  - `helm/frontend/templates/configmap.yaml`
- [x] Added/updated frontend, backend, and worker Kubernetes templates:
  - deployments
  - services
  - service accounts
  - frontend ingress
- [x] Added `helm/worker/secret.example.yaml` with dummy example values.
- [x] Updated Terraform outputs needed by Kubernetes deployment:
  - `rds_hostname`
  - `db_port`
  - `db_name`
  - `db_username`
  - `aws_region`
  - `s3_bucket_name`
  - `sns_topic_arn`
  - `db_password_secret_name`
- [x] Updated worker code/config direction so Kubernetes secret injection is used instead of requiring the app to fetch DB password directly from Secrets Manager.
- [x] Added `scripts/deploy_k8s.sh` in the previous task as the Helm deployment script that reads Terraform outputs.
- [x] Added `scripts/apply_terraform.sh` to handle Terraform init/validate/plan/apply separately.
- [x] Added `scripts/create_eks.sh` to create or reuse an EKS cluster with `eksctl` and update kubeconfig.
- [x] Added `scripts/destroy_eks.sh` to explicitly delete the EKS cluster only.
- [x] Added `scripts/deploy_all_k8s.sh` as the non-destroy orchestrator:
  1. Terraform app infrastructure
  2. EKS creation/reuse
  3. Helm deployment
- [x] Updated `deploy_all_k8s.sh` to call scripts using `bash`, so `chmod +x` is not required.
- [x] Verified script syntax with `bash -n` without creating AWS resources.
- [x] Verified `destroy_eks.sh --help` without deleting anything.

## Current script workflow

### Full non-destroy deployment

```bash
bash scripts/deploy_all_k8s.sh
```

This runs:

1. `bash scripts/apply_terraform.sh`
2. `bash scripts/create_eks.sh`
3. `bash scripts/deploy_k8s.sh`

### Non-interactive-ish run

```bash
bash scripts/deploy_all_k8s.sh --auto-approve --yes
```

- `--auto-approve` passes through to Terraform apply.
- `--yes` skips the EKS creation confirmation.

### Destroy EKS only

```bash
bash scripts/destroy_eks.sh
```

This intentionally does not destroy Terraform-managed RDS/S3/SNS/VPC/EC2/IAM resources.

## Terraform output status from previous task

The previous task checked:

```bash
terraform -chdir=terraform output -json | jq 'keys'
```

and received:

```json
[]
```

Meaning: Terraform currently had no usable outputs in state at that point. Before `deploy_k8s.sh` can succeed, Terraform must be applied or an existing state with outputs must be restored.

## Current checklist

- [x] Recover previous Cline conversation context.
- [x] Create separate Terraform/EKS/Kubernetes scripts instead of putting everything into `deploy_k8s.sh`.
- [x] Keep destroy separate from the deploy orchestrator.
- [x] Document recovery context in this file for future Cline sessions.
- [ ] Decide and verify final frontend exposure method: Ingress vs `LoadBalancer` Service vs another EKS-supported route.
- [ ] Verify compliance against the assignment PDF in the project root.
- [ ] Update the root README with the new script workflow.
- [ ] Review full git diff before commit.
- [ ] Commit all related Kubernetes/EKS/containerization changes.
- [ ] Push the current branch.

## Assignment compliance verification

The assignment PDF is present in the project root and should be consulted in a future session before final submission:

- `DevOps_on_AWS_-_-_k8s__Docker.pdf`

Do not assume this checklist is final until the PDF is re-read/extracted and compared directly to the implementation.

- [ ] Extract/read the assignment PDF text in a future session when performing final compliance review.
- [ ] Confirm the app runs in Kubernetes/EKS rather than on the old separate EC2 app servers.
- [ ] Confirm all three application services are represented as Kubernetes workloads:
  - [ ] frontend
  - [ ] backend
  - [ ] worker
- [ ] Confirm each microservice has its own Helm chart and values file, matching the chosen teacher-aligned direction.
- [ ] Confirm Helm is the mechanism that creates/updates Kubernetes Deployments, Services, ServiceAccounts, ConfigMaps, Secrets, and Ingress/LoadBalancer resources.
- [ ] Confirm the frontend is exposed externally in an assignment-appropriate way.
- [ ] Decide whether final frontend exposure should be documented as Ingress or LoadBalancer after checking the actual EKS setup.
- [ ] Confirm backend and worker stay internal-only unless the PDF requires otherwise.
- [ ] Confirm worker can connect to external AWS services needed by the app:
  - [ ] RDS PostgreSQL
  - [ ] S3
  - [ ] SNS
- [ ] Confirm DB credentials are automated from Terraform/RDS creation into a Kubernetes Secret, rather than manually typed for normal deployment.
- [ ] Confirm generated Terraform outputs feed the Helm deployment flow.
- [ ] Confirm container images are built and pushed to Docker Hub repositories used by the Helm values.
- [ ] Confirm security-related Kubernetes choices are documented or implemented where required:
  - [ ] non-root containers/securityContext
  - [ ] ServiceAccounts
  - [ ] least-privilege AWS access direction
  - [ ] clear secret handling
- [ ] Collect final evidence commands/output for submission:
  - [ ] `kubectl get pods -n devops-app -o wide`
  - [ ] `kubectl get svc -n devops-app -o wide`
  - [ ] `kubectl get ingress -n devops-app`
  - [ ] `helm list -n devops-app`
  - [ ] app health checks through the chosen external endpoint
  - [ ] worker/RDS/S3/SNS behavior evidence if required by the PDF

## Planned next improvements

- [ ] Add AWS-side idle cleanup for EKS so the cluster can be deleted after being idle/unused for too long without requiring the local machine to stay on.
- [ ] Decide later whether EKS should move from `eksctl` script management into Terraform.
- [ ] Update documentation more thoroughly after the restructuring stabilizes.
- [ ] Finalize frontend exposure after checking actual EKS capabilities and assignment requirements.
- [ ] Add verification/evidence commands for assignment submission:
  - `kubectl get pods -n devops-app`
  - `kubectl get svc -n devops-app`
  - `helm list -n devops-app`
  - ingress/load balancer checks
  - backend/worker health checks
- [ ] Validate the full deployment on a real EKS cluster after confirming AWS cost expectations.
