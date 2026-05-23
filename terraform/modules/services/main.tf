resource "aws_cloudwatch_metric_alarm" "billing_over_20" {
  alarm_name          = "${var.name_prefix}-${var.environment}-${var.billing_alarm_name}"
  alarm_description   = "Alarm when estimated AWS charges exceed 20 USD"
  namespace           = "AWS/Billing"
  metric_name         = "EstimatedCharges"
  statistic           = "Maximum"
  period              = 21600
  evaluation_periods  = 1
  threshold           = 20
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    Currency = "USD"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-${var.billing_alarm_name}"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}
