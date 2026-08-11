# Kubernetes / EKS assignment progress

Project rules and the rolling current status have moved to
[`/home/geeta/Project1/.clinerules/`](.clinerules/).

Start with
[`/home/geeta/Project1/.clinerules/90-current-project-status.md`](.clinerules/90-current-project-status.md).
Full pre-migration history remains in
`/home/geeta/Project1/misc/recovery/K8S_EKS_PROGRESS.md.full-backup-20260730T234556Z`
(local, ignored recovery material).

## User action checklist

- [x] Keep the frontend's existing Kubernetes `LoadBalancer` Service as the only
  public application endpoint.
- [x] Keep Jenkins private as ClusterIP-only with no ALB or Ingress.
- [x] Seed Jenkins jobs from a short-lived in-cluster Kubernetes Job so chart admin
  credentials remain inside the cluster.
- [ ] During an authorized deployment, verify frontend external access and the
  private Jenkins Service/job-seeding path.
- [ ] Use `kubectl port-forward` only as an operator fallback when Jenkins UI access
  is required, and capture non-secret verification evidence.