output "worker_role_arn" {
  value = aws_iam_role.worker.arn
}

output "jenkins_ci_role_arn" {
  value = aws_iam_role.jenkins_ci.arn
}

output "jenkins_deployer_role_arn" {
  value = aws_iam_role.jenkins_deployer.arn
}