provider "aws" {}

data "aws_iam_policy_document" "stack-sets-administration-role-assume-policy" {
  version = "2012-10-17"
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = ["cloudformation.amazonaws.com"]
      type = "Service"
    }
  }
}

locals {
  execution-role-name = "AWSCloudFormationStackSetExecutionRole"
}

data "aws_iam_policy_document" "assume-execution-role" {
  version = "2012-10-17"
  statement {
    actions = ["sts:AssumeRole"]
    effect = "Allow"
    resources = ["arn:aws:iam::*:role/${local.execution-role-name}"]
  }
}

resource "aws_iam_role" "stack-sets-administration-role" {
  assume_role_policy = data.aws_iam_policy_document.stack-sets-administration-role-assume-policy.json
  name = "AWSCloudFormationStackSetAdministrationRole"

  inline_policy {
    policy = data.aws_iam_policy_document.assume-execution-role.json
  }
}

data "aws_iam_policy_document" "stack-sets-execution-role-assume-policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = [aws_iam_role.stack-sets-administration-role.arn]
      type = "AWS"
    }
  }
}

resource "aws_iam_role" "stack-sets-execution-role" {
  assume_role_policy = data.aws_iam_policy_document.stack-sets-execution-role-assume-policy.json
  name = local.execution-role-name

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonVPCFullAccess",
    "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess",
    "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
  ]
}

resource "aws_cloudformation_stack_set" "vpc-stack-set" {
  name = "vpc-stack-set"
  template_body = file("${path.module}/template.yaml")
  permission_model = "SELF_MANAGED"
  administration_role_arn = aws_iam_role.stack-sets-administration-role.arn
  execution_role_name = aws_iam_role.stack-sets-execution-role.name
  call_as = "SELF"
  parameters = {
    "CidrBlock": "10.0.0.0/16"
  }

  operation_preferences {
    region_concurrency_type = "PARALLEL"
    max_concurrent_count = 2
  }
}

locals {
  instance-regions = [
    "eu-west-1",
    "us-east-1"
  ]
}

resource "aws_cloudformation_stack_set_instance" "stack-set-instances" {
  for_each = toset(local.instance-regions)
  stack_set_name = aws_cloudformation_stack_set.vpc-stack-set.id
  region = each.value
}