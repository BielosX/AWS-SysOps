output "instance-id" {
  value = aws_instance.demo-instances.id
}

output "instance-arn" {
  value = aws_instance.demo-instances.arn
}

output "role-arn" {
  value = aws_iam_role.instance-role.arn
}