output "endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "db_subnet_group_name" {
  value = aws_db_subnet_group.project.name
}