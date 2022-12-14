data "aws_iam_policy_document" "lambda-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "lambda-role" {
  assume_role_policy = data.aws_iam_policy_document.lambda-assume-role.json
  managed_policy_arns = var.managed-policy-arns
}

data "archive_file" "lambda-zip" {
  source_file = var.file-path
  output_path = "${path.module}/lambda.zip"
  type = "zip"
}

resource "aws_lambda_function" "lambda" {
  function_name = var.function-name
  runtime = "python3.9"
  handler = var.handler
  role = aws_iam_role.lambda-role.arn
  filename = data.archive_file.lambda-zip.output_path
  source_code_hash = data.archive_file.lambda-zip.output_base64sha256
  environment {
    variables = var.environment-variables
  }
}