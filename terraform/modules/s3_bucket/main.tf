resource "aws_s3_bucket" "machine_catalog" {
  bucket = var.bucket_name

  tags = merge(var.common_tags, {
    Name        = var.bucket_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}