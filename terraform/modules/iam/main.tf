resource "aws_iam_role" "instance_role" {
  name = "${var.name_prefix}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-ec2-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.name_prefix}-${var.environment}-ec2-profile"
  role = aws_iam_role.instance_role.name

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-ec2-profile"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "allow_s3_read" {
  name = "${var.name_prefix}-${var.environment}-allow-s3-read"
  role = aws_iam_role.instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
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
  name = "${var.name_prefix}-${var.environment}-sns-publish"
  role = aws_iam_role.instance_role.id

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
  name = "${var.name_prefix}-${var.environment}-s3-write-instances"
  role = aws_iam_role.instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.bucket_name}/instances.json"
      }
    ]
  })
}

resource "aws_iam_role_policy" "secretsmanager_read_db_password" {
  name = "${var.name_prefix}-${var.environment}-secretsmanager-read-db-password"
  role = aws_iam_role.instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.db_password_secret_name}*"
      }
    ]
  })
}