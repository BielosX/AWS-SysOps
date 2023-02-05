output "instance-id" {
  value = aws_instance.demo-instance.id
}

output "instance-arn" {
  value = aws_instance.demo-instance.arn
}

output "role-arn" {
  value = aws_iam_role.instance-role.arn
}

output "private-ip" {
  value = aws_instance.demo-instance.private_ip
}

output "eip-public-ip" {
  value = var.eip ? aws_eip.eip[0].public_ip : null
}