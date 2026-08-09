output "vpc_id" {
  value = aws_vpc.project.id
}

output "db_security_group_id" {
  value = aws_security_group.db.id
}

output "db_security_group_ids" {
  value = [aws_security_group.db.id]
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "eks_public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "eks_private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "db_subnet_id" {
  value = aws_subnet.private[0].id
}

output "db_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  value = var.enable_nat_gateway ? aws_nat_gateway.project[0].id : null
}