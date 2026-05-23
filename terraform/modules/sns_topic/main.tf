resource "aws_sns_topic" "worker_notifications" {
  name = "${var.name_prefix}-${var.environment}-${var.topic_name}"

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-${var.topic_name}"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_sns_topic_subscription" "worker_email" {
  topic_arn = aws_sns_topic.worker_notifications.arn
  protocol  = "email"
  endpoint  = var.subscription_email
}