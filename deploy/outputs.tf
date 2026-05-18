output "ssm_box_id" {
  value = aws_instance.ssm_box.id
}

output "aws_subnet_private_ids" {
  value = [for subnet in aws_subnet.private : subnet.id]
}

output "aws_subnet_public_ids" {
  value = [for subnet in aws_subnet.public : subnet.id]
}
