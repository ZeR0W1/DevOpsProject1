# Architecture and ownership rules

## Infrastructure and lifecycle ownership

- Terraform owns AWS infrastructure, including VPC networking, EKS, IAM
  integrations, RDS PostgreSQL, S3/SNS dependencies, and related security
  boundaries. Do not create competing infrastructure ownership implicitly through
  shell scripts, `eksctl`, Helm, Kubernetes manifests, or Ansible, unless asked to by the user.
- Thin shell helpers are acceptable when they execute reviewed Terraform, Ansible,
  Helm, or inspection commands without becoming an independent resource owner.
  Terraform state/configuration remains authoritative for AWS resources, and
  Ansible remains authoritative for lifecycle ordering.
- Ansible is the official lifecycle orchestrator. The intended create flow is
  Terraform infrastructure and AWS identity provisioning; kubeconfig and cluster
  prerequisite setup; Jenkins namespace, storage, Helm release, deployer RBAC and
  workload-identity binding; Jenkins CI/CD job seeding; initial application S3
  content upload; Kubernetes application secret and configuration preparation;
  then application deployment through the standalone CD job.
- Jenkins is part of the managed platform lifecycle, not an application Helm
  release. Its AWS IAM and EKS identity resources belong to Terraform; Ansible
  should orchestrate its Helm-based in-cluster deployment and job configuration.
  Temporary shell helpers must not become a second owner of those resources.
- Teardown must be intentional, cost-aware, dependency-ordered, and implemented as
  a separate lifecycle path. Remove application entry points and releases before
  stateful Jenkins storage and identity bindings, then remove EKS and audit
  residual billable resources.
- Transitional shell/`eksctl` resources are not Terraform-owned unless a reviewed
  migration plan explicitly imports or recreates them. Never infer ownership from
  matching names alone.
- Terraform creates the new private application-content S3 bucket and its security
  controls. Ansible uploads the initial versioned `index.html` object after
  Terraform outputs are available; application Helm/CD configuration consumes the
  bucket and object identifiers. At runtime, the worker persists machine records
  in Terraform-owned RDS PostgreSQL as the primary structured datastore, exports
  the resulting catalog locally, and writes the synchronized backup only to S3
  object `instances.json` using narrowly scoped Pod Identity permissions.
  Initial-content upload credentials are separate from workload permissions. Do
  not use the application bucket as the Terraform state backend.

## Application and deployment boundaries

- The application consists of independently deployable frontend, backend, and
  worker services. Docker builds immutable images; the Helm charts in
  `helm/frontend`, `helm/backend`, and `helm/worker` deploy them independently.
- Jenkins retains separate CI and CD jobs. CI checks code and charts, builds and
  publishes all three services with one immutable tag, and may trigger CD. Only CD
  changes application resources in EKS.
- Keep Jenkinsfiles focused on orchestration. Move reusable lifecycle operations
  toward an Ansible `kubernetes.core.helm` workflow, a reviewed helper, or a
  Jenkins Shared Library without merging the CI and CD ownership boundaries.
- Manage non-secret runtime configuration through Helm/ConfigMaps. Keep real
  secrets out of Git and images; commit examples and documented creation steps
  only.

## Kubernetes architecture invariants

- Run application workloads in a dedicated namespace, never `default`.
- Provide a Deployment for frontend, backend, and worker with immutable image
  tags, meaningful labels/selectors, resource requests/limits, readiness and
  liveness probes, and least-privilege container security contexts.
- Expose the application frontend publicly. Backend and worker remain internal;
  database access is restricted to required callers. Jenkins may use a separate
  controlled administrative ALB Ingress: although AWS classifies it as
  internet-facing, its security group must allow HTTPS only from the approved
  admin CIDR, TLS and Jenkins authentication are mandatory, and its ClusterIP
  Service remains unexposed directly. Do not describe that endpoint as generally
  public or broaden it to `0.0.0.0/0`.
- Use distinct ServiceAccounts and narrowly scoped AWS/Kubernetes permissions when
  services have different responsibilities. Never grant the application
  `cluster-admin`.
- Keep RDS, S3, and SNS outside the cluster and document endpoints, credential
  handling, identity authorization, network paths, and security boundaries.
- For EKS workload AWS access, prefer short-lived workload identity. The worker
  uses EKS Pod Identity; EBS CSI uses IRSA. Document any broader node-role policy
  as an explicit trade-off.

## Documentation and compliance

- The assignment PDF is the source of truth for submission compliance. Maintain a
  reproducible README covering architecture, image build/publish, namespace and
  secret setup, deployment, verification, teardown, security, and trade-offs.
- The README must identify the Jenkins ALB as a separate controlled administrative
  endpoint and justify its internet-facing AWS scheme: no VPN is assumed in scope,
  HTTPS is limited to the approved admin CIDR, TLS and Jenkins authentication are
  mandatory, the backend Service remains ClusterIP, and the added controller/ALB
  cost and teardown path are explicit. Distinguish it from the generally public
  application frontend and document port-forward only as a fallback.
- Maintain an architecture diagram showing the cluster, namespace, workloads,
  services, public entry point, ConfigMaps, Secrets, ServiceAccounts, RDS, S3,
  SNS, VPC/subnets/node groups, communication direction, and public/private/
  internal trust boundaries.
- Preserve evidence for nodes, namespaces, workloads, services, ingress or load
  balancer, pod details/logs, external access, service-to-service and database
  communication, S3/SNS behavior, and workload recovery.