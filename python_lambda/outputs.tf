output "function-name" {
  value = aws_lambda_function.lambda.function_name
}

output "function-arn" {
  value = aws_lambda_function.lambda.arn
}

output "invoke-arn" {
  value = aws_lambda_function.lambda.invoke_arn
}

output "role-name" {
  value = aws_iam_role.lambda-role.name
}