provider "aws" {}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  region = data.aws_region.current.name
  account-id = data.aws_caller_identity.current.account_id
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

module "private-bucket" {
  source = "../private_bucket"
  bucket-name = "statsd-demo-${local.region}-${local.account-id}"
}

resource "aws_security_group" "instance-sg" {
  vpc_id = data.aws_vpc.default.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 22
    to_port = 22
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 8080
    protocol = "tcp"
    to_port = 8080
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }
}

resource "aws_ssm_parameter" "cloudwatch-agent-config" {
  name = "statsd-demo-cloudwatch-agent-config"
  type = "String"
  value = file("${path.module}/cw_agent_config.json")
}

module "instance" {
  source = "../amzn_linux2_instance"
  instance-type = "t3.micro"
  name = "statsd-demo"
  security-group-ids = [aws_security_group.instance-sg.id]
  subnet-id = data.aws_subnets.public.ids[0]
  user-data = templatefile("${path.module}/init.sh", {
    cw_config_param: aws_ssm_parameter.cloudwatch-agent-config.id
  })
  managed-policy-arns = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  ]
}

resource "aws_codedeploy_app" "demo-app" {
  name = "demo-app"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_config" "deployment-config" {
  deployment_config_name = "demo-app-deployment-config"
  minimum_healthy_hosts {
    type = "HOST_COUNT"
    value = 0
  }
}

data "aws_iam_policy_document" "code-deploy-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["codedeploy.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "code-deploy-service-role" {
  assume_role_policy = data.aws_iam_policy_document.code-deploy-assume-role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  ]
}

resource "aws_codedeploy_deployment_group" "demo-app-deployment-group" {
  app_name = aws_codedeploy_app.demo-app.name
  deployment_group_name = "demo-app-deployment-group"
  service_role_arn = aws_iam_role.code-deploy-service-role.arn
  deployment_config_name = aws_codedeploy_deployment_config.deployment-config.id

  ec2_tag_set {
    ec2_tag_filter {
      key = "Name"
      type = "KEY_AND_VALUE"
      value = "statsd-demo"
    }
  }
}