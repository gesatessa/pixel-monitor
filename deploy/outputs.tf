output "ssm_box_id" {
  value = aws_instance.ssm_box.id
}

output "aws_subnet_private_ids" {
  value = [for subnet in aws_subnet.private : subnet.id]
}

output "aws_subnet_public_ids" {
  value = [for subnet in aws_subnet.public : subnet.id]
}

output "postgres_address" {
  value = local.postgres_instance.address
}

output "postgres_secret_arn" {
  value = local.postgres_instance.master_user_secret[0].secret_arn
}
