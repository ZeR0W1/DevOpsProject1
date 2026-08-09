resource "aws_s3_bucket" "machine_catalog" {
  bucket        = var.bucket_name
  force_destroy = false

  tags = merge(var.common_tags, {
    Name        = var.bucket_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "ApplicationContentAndCatalog"
  })
}

resource "aws_s3_bucket_ownership_controls" "machine_catalog" {
  bucket = aws_s3_bucket.machine_catalog.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "machine_catalog" {
  bucket = aws_s3_bucket.machine_catalog.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "machine_catalog" {
  bucket = aws_s3_bucket.machine_catalog.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }

    bucket_key_enabled = true
  }
}

data "aws_iam_policy_document" "require_tls" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.machine_catalog.arn,
      "${aws_s3_bucket.machine_catalog.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "require_tls" {
  bucket = aws_s3_bucket.machine_catalog.id
  policy = data.aws_iam_policy_document.require_tls.json

  depends_on = [aws_s3_bucket_public_access_block.machine_catalog]
}