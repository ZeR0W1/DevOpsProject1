data "tls_certificate" "cluster_oidc" {
  url = aws_eks_cluster.project.identity[0].oidc[0].issuer
}

locals {
  oidc_issuer_hostpath = trimprefix(aws_eks_cluster.project.identity[0].oidc[0].issuer, "https://")
}

resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-cluster-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-node-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_registry_policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_cluster" "project" {
  name                      = var.cluster_name
  role_arn                  = aws_iam_role.cluster.arn
  version                   = var.cluster_version
  enabled_cluster_log_types = var.enabled_cluster_log_types

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.endpoint_public_access_cidrs
  }

  tags = merge(var.common_tags, {
    Name        = var.cluster_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

check "node_group_scaling" {
  assert {
    condition = (
      var.node_min_size <= var.node_desired_size &&
      var.node_desired_size <= var.node_max_size
    )
    error_message = "EKS node scaling must satisfy node_min_size <= node_desired_size <= node_max_size."
  }
}

resource "aws_iam_openid_connect_provider" "cluster" {
  url             = aws_eks_cluster.project.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster_oidc.certificates[0].sha1_fingerprint]

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-oidc"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_iam_role" "ebs_csi" {
  name = "${var.cluster_name}-ebs-csi-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.cluster.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_issuer_hostpath}:aud" = "sts.amazonaws.com"
          "${local.oidc_issuer_hostpath}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-ebs-csi-controller-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_node_group" "private" {
  cluster_name    = aws_eks_cluster.project.name
  node_group_name = "${var.cluster_name}-private-nodes"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-private-nodes"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_registry_policy
  ]
}

resource "aws_eks_addon" "core" {
  for_each = toset([
    "coredns",
    "eks-pod-identity-agent",
    "kube-proxy",
    "metrics-server",
    "vpc-cni"
  ])

  cluster_name                = aws_eks_cluster.project.name
  addon_name                  = each.value
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_node_group.private]
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.project.name
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = aws_iam_role.ebs_csi.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [
    aws_eks_node_group.private,
    aws_iam_role_policy_attachment.ebs_csi
  ]
}