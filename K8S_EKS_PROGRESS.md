# Kubernetes / EKS assignment progress

Project rules and the rolling current status have moved to
[`/home/geeta/Project1/.clinerules/`](.clinerules/).

Start with
[`/home/geeta/Project1/.clinerules/90-current-project-status.md`](.clinerules/90-current-project-status.md).
Full pre-migration history remains in
`/home/geeta/Project1/misc/recovery/K8S_EKS_PROGRESS.md.full-backup-20260730T234556Z`
(local, ignored recovery material).

## User action checklist

- [ ] Consult the professor about the provisional Jenkins access design:
  AWS Load Balancer Controller-managed, internet-facing ALB Ingress with HTTPS
  restricted to the approved admin CIDR, mandatory TLS and Jenkins authentication,
  and a ClusterIP Jenkins Service.
- [ ] Ask whether that controlled administrative endpoint satisfies the assignment
  or whether Jenkins must instead use a private SSM or bastion access path.
- [ ] Confirm whether the professor considers an AWS `internet-facing` ALB to be
  acceptable when it is not reachable outside the approved source CIDR.
- [ ] Record the professor's answer in
  [`.clinerules/90-current-project-status.md`](.clinerules/90-current-project-status.md)
  before implementing Jenkins access resources.
- [ ] If the ALB approach is retained, confirm the DNS name/domain and TLS
  certificate approach, then document its security rationale, added cost, and
  teardown path in the primary README.
- [ ] If SSM or a bastion is required, review its IAM, network path, operator
  workflow, cost, and teardown before replacing the provisional ALB design.