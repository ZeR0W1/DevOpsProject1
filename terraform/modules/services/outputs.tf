output "billing_alarm_name" {
  value = aws_cloudwatch_metric_alarm.billing_over_20.alarm_name
}
