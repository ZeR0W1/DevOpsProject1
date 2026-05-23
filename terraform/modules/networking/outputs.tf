output "frontend_security_group_id" {
  value = aws_security_group.frontend_http.id
}

output "backend_security_group_id" {
  value = aws_security_group.backend_api.id
}

output "worker_security_group_id" {
  value = aws_security_group.worker_app.id
}

output "db_security_group_id" {
  value = aws_security_group.db.id
}

output "db_security_group_ids" {
  value = [aws_security_group.db.id]
}

output "public_subnet_id" {
  value = var.public_subnet_id
}

output "db_subnet_id" {
  value = var.db_subnet_id
}

output "db_subnet_ids" {
  value = [var.public_subnet_id, var.db_subnet_id]
}

output "public_availability_zone" {
  value = var.public_availability_zone
}