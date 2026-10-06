output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "security_group_id" {
  value = aws_security_group.databricks.id
}

output "nat_enabled" {
  value = var.enable_nat
}