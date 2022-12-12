provider "aws" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "instance-sg" {
  vpc_id = data.aws_vpc.default.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol  = "tcp"
    from_port = 80
    to_port   = 80
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol  = "tcp"
    from_port = 443
    to_port   = 443
  }
}

module "amazon-linux-2-instance" {
  source = "../amzn_linux2_instance"
  instance-type = "t3.nano"
  name = "demo"
  security-group-ids = [aws_security_group.instance-sg.id]
  subnet-id = data.aws_subnets.default.ids[0]
}

resource "aws_cloudwatch_event_rule" "snapshot-created" {
  event_pattern = <<-EOT
  {
    "source": ["aws.ec2"],
    "detail-type": ["EBS Snapshot Notification"],
    "detail": {
      "event": ["createSnapshot"],
      "result": ["succeeded"]
    }
  }
  EOT
}

data "archive_file" "lambda" {
  source_file = "${path.module}/main.py"
  output_path = "${path.module}/lambda.zip"
  type = "zip"
}

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
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
}

data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name
}

resource "aws_lambda_function" "copy-snapshot-function" {
  function_name = "copy-snapshot"
  role = aws_iam_role.lambda-role.arn
  handler = "main.handle"
  runtime = "python3.9"
  timeout = 60
  filename = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  environment {
    variables = {
      TARGET_REGION: "us-east-1"
      SOURCE_REGION: local.region
      SNAPSHOT_NAME: "demo-snapshot"
    }
  }
}

resource "aws_lambda_permission" "lambda-permission" {
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.copy-snapshot-function.function_name
  principal = "events.amazonaws.com"
}

resource "aws_cloudwatch_event_target" "target" {
  arn  = aws_lambda_function.copy-snapshot-function.arn
  rule = aws_cloudwatch_event_rule.snapshot-created.name
}