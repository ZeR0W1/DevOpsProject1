resource "aws_iam_role" "worker" {
  name = "${var.name_prefix}-${var.environment}-worker-pod-identity"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-worker-pod-identity"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_iam_role_policy" "allow_s3_read" {
  name = "${var.name_prefix}-${var.environment}-worker-s3-read"
  role = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Read-only access for objects inside the project bucket.
        Sid    = "Statement1"
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = [
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "sns_publish" {
  name = "${var.name_prefix}-${var.environment}-worker-sns-publish"
  role = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "VisualEditor0"
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = var.sns_topic_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_write_instances" {
  name = "${var.name_prefix}-${var.environment}-worker-s3-write-instances"
  role = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Restrict write permission to the generated catalog object only.
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.bucket_name}/instances.json"
      }
    ]
  })
}

resource "aws_iam_role" "jenkins_ci" {
  name = "${var.name_prefix}-${var.environment}-jenkins-ci-pod-identity"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-jenkins-ci-pod-identity"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_iam_role_policy" "jenkins_ci_frontend_content" {
  name = "${var.name_prefix}-${var.environment}-jenkins-ci-frontend-content"
  role = aws_iam_role.jenkins_ci.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      Resource = "arn:aws:s3:::${var.bucket_name}/index.html"
    }]
  })
}

resource "aws_iam_role" "jenkins_deployer" {
  name = "${var.name_prefix}-${var.environment}-jenkins-deployer-pod-identity"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-jenkins-deployer-pod-identity"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_iam_role_policy" "jenkins_deployer_frontend_content" {
  name = "${var.name_prefix}-${var.environment}-jenkins-deployer-frontend-content"
  role = aws_iam_role.jenkins_deployer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${var.bucket_name}/index.html"
      },
      {
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = var.eks_cluster_arn
      }
    ]
  })
}
