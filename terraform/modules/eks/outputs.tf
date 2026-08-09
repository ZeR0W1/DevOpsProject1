output "cluster_name" {
  value = aws_eks_cluster.project.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.project.endpoint
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

output "pod_identity_agent_cluster_name" {
  description = "Cluster name emitted only after the EKS Pod Identity Agent add-on is active"
  value       = aws_eks_addon.core["eks-pod-identity-agent"].cluster_name
}