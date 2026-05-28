output "vpc_id" {
  value = aws_vpc.project.id
}

output "frontend_security_group_id" {
  value = aws_security_group.frontend_http.id
}

output "backend_security_group_id" {
  value = aws_security_group.backend_api.id
}

output "worker_security_group_id" {
  value = aws_security_group.worker_app.id
}

output "ssh_admin_security_group_id" {
  value = var.enable_ssh_ingress ? aws_security_group.ssh_admin[0].id : null
}

output "db_security_group_id" {
  value = aws_security_group.db.id
}

output "db_security_group_ids" {
  value = [aws_security_group.db.id]
}

output "app_subnet_id" {
  value = aws_subnet.public.id
}

output "db_subnet_id" {
  value = aws_subnet.db.id
}

output "db_subnet_ids" {
  value = [aws_subnet.public.id, aws_subnet.db.id]
}

output "app_availability_zone" {
  value = var.availability_zones[0]
}