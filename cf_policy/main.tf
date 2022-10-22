provider "aws" {}

data "aws_ami" "amazon-linux-2" {
  owners = ["amazon"]
  most_recent = true
  filter {
    name = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_iam_policy_document" "cf-policy" {
  statement {
    effect = "Deny"
    actions = ["Update:*"] // Update:Modify, Update:Replace, Update:Delete
    principals {
      identifiers = ["*"]
      type = "*"
    }
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = ["Update:Modify"]
    principals {
      identifiers = ["*"]
      type = "*"
    }
    resources = ["LogicalResourceId/DemoQueue"]
  }

  statement {
    effect = "Allow"
    actions = ["Update:Modify"]
    principals {
      identifiers = ["*"]
      type = "*"
    }
    resources = ["*"]
    condition {
      test = "StringEquals"
      variable = "ResourceType"
      values = ["AWS::EC2::Instance"]
    }
  }
}

resource "aws_cloudformation_stack" "demo-stack" {
  name = "demo-stack"
  template_body = file("${path.module}/template.yaml")
  parameters = {
    "QueueName": "demo-queue"
    "Ami": data.aws_ami.amazon-linux-2.image_id
    "InstanceAZ": data.aws_availability_zones.available.names[0]
    "InstanceType": "t3.micro"
  }
  policy_body = data.aws_iam_policy_document.cf-policy.json
  on_failure = "DO_NOTHING"
}