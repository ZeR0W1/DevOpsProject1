output "frontend_public_ip" {
  value = aws_instance.frontend.public_ip
}

output "backend_private_ip" {
  value = aws_instance.backend.private_ip
}

output "worker_private_ip" {
  value = aws_instance.worker.private_ip
}

output "worker_launch_template_id" {
  value = aws_launch_template.worker_template.id
}