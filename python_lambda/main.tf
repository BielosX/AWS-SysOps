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
}

resource "aws_iam_role_policy_attachment" "managed-policy-attachment" {
  for_each = toset(var.managed-policy-arns)
  policy_arn = each.key
  role = aws_iam_role.lambda-role.name
}

resource "local_file" "content" {
  count = var.code == "" ? 0 : 1
  filename = "${path.module}/main.py"
  content = var.code
}

data "archive_file" "lambda-zip" {
  source_file = var.code == "" ? var.file-path : local_file.content[0].filename
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
  timeout = var.timeout
  dynamic "environment" {
    for_each = length(var.environment-variables) > 0 ? [1] : []
    content {
      variables = var.environment-variables
    }
  }
}