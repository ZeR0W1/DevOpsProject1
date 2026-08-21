# Architecture and ownership rules

## Infrastructure and lifecycle ownership

- In the target architecture, Terraform owns newly created AWS infrastructure
  represented in its state, including VPC networking, EKS, IAM integrations, RDS
  PostgreSQL, S3/SNS dependencies, and related security boundaries. Current
  ownership is determined by Terraform state and `90-current-project-status.md`;
  matching configuration or names do not confer ownership. Do not create
  competing AWS infrastructure ownership through shell scripts, `eksctl`, Helm,
  Kubernetes manifests, or Ansible.
- Thin shell helpers may execute reviewed Terraform, Ansible, Helm, or inspection
  commands without becoming an independent resource owner. Terraform state is
  authoritative for Terraform-owned AWS resources, and Ansible remains
  authoritative for lifecycle ordering.
- Ansible is the official lifecycle orchestrator. The intended create flow is
  Terraform infrastructure and AWS identity provisioning; kubeconfig and cluster
  prerequisite setup; Jenkins namespace, storage, Helm release, deployer RBAC and
  workload-identity binding; Jenkins CI/CD job seeding; initial application S3
  content upload; Kubernetes application secret and configuration preparation;
  then application deployment through the standalone CD job.
- In the target model, Jenkins is part of the managed platform lifecycle, not an
  application Helm release. Its AWS IAM and EKS identity resources belong to
  Terraform; Ansible orchestrates its Helm-based in-cluster deployment and job
  configuration. Current implementation progress is tracked in
  `90-current-project-status.md`.
- Teardown uses a separate dependency-ordered lifecycle path: application entry
  points/releases, Jenkins state and identity bindings, then one Terraform destroy
  for the Terraform-owned main stack. Residual billable-resource inspection is a
  separate read-only operational check.
- Terraform creates the private application-content S3 bucket and its security
  controls. Ansible uploads the initial `index.html` object after Terraform
  outputs are available; application Helm/CD configuration consumes the bucket
  and object identifiers.
- The application-content bucket and Terraform remote-state bucket are separate
  infrastructure boundaries.

## Application and deployment boundaries

- The application consists of independently deployable frontend, backend, and
  worker services. Docker builds immutable images; the Helm charts in
  `helm/frontend`, `helm/backend`, and `helm/worker` deploy them independently.
- Jenkins retains separate CI and CD jobs. CI checks code and charts, builds and
  publishes all three services with one immutable tag, and may trigger CD. Only
  CD deploys or changes application workloads in EKS; Ansible first prepares the
  namespace, Secrets, ConfigMaps, identity, and other deployment prerequisites.
- Keep Jenkinsfiles focused on orchestration. Move reusable lifecycle operations
  toward an Ansible `kubernetes.core.helm` workflow, a reviewed helper, or a
  Jenkins Shared Library without merging the CI and CD ownership boundaries.
- Manage non-secret runtime configuration through Helm/ConfigMaps. Secret storage
  and inspection are governed by `03-cloud-and-terraform-safety.md`.

## Data and AWS service boundaries

- At runtime, the worker persists machine records in Terraform-owned RDS
  PostgreSQL as the primary structured datastore.
- The worker exports the resulting catalog locally and writes the synchronized
  backup only to S3 object `instances.json` using narrowly scoped Pod Identity
  permissions.
- The worker emits SNS notifications using its workload identity.
- Initial-content upload credentials are separate from runtime workload
  permissions.

## Kubernetes architecture invariants

- Run application workloads in a dedicated namespace, never `default`.
- Provide a Deployment for frontend, backend, and worker with immutable image
  tags, meaningful labels/selectors, resource requests/limits, readiness and
  liveness probes, and least-privilege container security contexts.
- Expose the application frontend publicly. Backend and worker remain internal;
  database access is restricted to required callers.
- A Terraform-owned shared Application Load Balancer is the only public
  application/platform entry point. Its default route serves the frontend through
  a fixed NodePort, while a higher-priority rule forwards only the exact Jenkins
  GitHub webhook path from the current GitHub `hooks` CIDRs to a separate fixed
  NodePort. All other Jenkins paths remain unreachable through the ALB, and HMAC
  validation is required before a webhook can trigger CI. Jenkins' normal Service
  remains ClusterIP-only; use short-lived in-cluster lifecycle automation and an
  operator `kubectl port-forward` only when interactive UI access is required.
- Use distinct ServiceAccounts and narrowly scoped AWS/Kubernetes permissions
  when services have different responsibilities. Never grant application
  workloads `cluster-admin`.
- Keep RDS, S3, and SNS outside the cluster and document endpoints, credential
  handling, identity authorization, network paths, and security boundaries.
- For EKS workload AWS access, prefer short-lived workload identity. The worker
  uses EKS Pod Identity; EBS CSI uses IRSA. Document any broader node-role policy
  as an explicit trade-off.

## Documentation and compliance

- The assignment PDF is the source of truth for submission compliance.
- Maintain a reproducible README covering architecture, image build/publish,
  namespace and secret setup, deployment, verification, teardown, security, and
  trade-offs.
- The README must distinguish the public shared ALB and its restricted webhook
  route from private ClusterIP-only Jenkins, document the fixed frontend and
  webhook NodePort boundaries, in-cluster job seeding, and credential handling,
  and provide `kubectl port-forward` as the optional UI fallback.
- Maintain an architecture diagram showing the cluster, namespace, workloads,
  services, public entry point, ConfigMaps, Secrets, ServiceAccounts, RDS, S3,
  SNS, VPC/subnets/node groups, communication direction, and public/private/
  internal trust boundaries.
- Preserve submission evidence for nodes, namespaces, workloads, services,
  ingress or load balancer, pod details/logs, external access,
  service-to-service and database communication, S3/SNS behavior, and workload
  recovery.
