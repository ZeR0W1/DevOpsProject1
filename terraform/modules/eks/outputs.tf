output "cluster_name" {
  value = aws_eks_cluster.project.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.project.endpoint
}

output "cluster_arn" {
  value = aws_eks_cluster.project.arn
}

output "cluster_security_group_id" {
  value = aws_eks_cluster.project.vpc_config[0].cluster_security_group_id
}

output "oidc_issuer_url" {
  value = aws_eks_cluster.project.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.cluster.arn
}

output "node_role_arn" {
  value = aws_iam_role.node.arn
}

output "node_autoscaling_group_names" {
  description = "Managed node Auto Scaling groups available for Terraform-owned load balancer target-group attachment"
  value = [
    for group in aws_eks_node_group.private.resources[0].autoscaling_groups : group.name
  ]
}

output "node_alb_security_group_id" {
  description = "Additional managed-node security group reserved for Terraform-owned ALB NodePort ingress"
  value       = aws_security_group.node_alb.id
}

output "pod_identity_agent_cluster_name" {
  description = "Cluster name emitted only after the EKS Pod Identity Agent add-on is active"
  value       = aws_eks_addon.core["eks-pod-identity-agent"].cluster_name
}