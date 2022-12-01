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
    protocol = "tcp"
    from_port = 80
    to_port = 80
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 22
    to_port = 22
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 443
    to_port = 443
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name
  account-id = data.aws_caller_identity.current.account_id
}

module "private-bucket" {
  source = "../private_bucket"
  bucket-name = "inventory-${local.region}-${local.account-id}"
}

resource "aws_ssm_association" "inventory" {
  name = "AWS-GatherSoftwareInventory"
  parameters = {
    applications = "Enabled"
    awsComponents = "Enabled"
    networkConfig = "Enabled"
    windowsUpdates = "Disabled"
    instanceDetailedInformation = "Enabled"
    services = "Enabled"
    windowsRoles = "Disabled"
    customInventory = "Disabled"
    billingInfo = "Disabled"
  }

  schedule_expression = "rate(30 minutes)" // 30 minutes is minimum

  output_location {
    s3_bucket_name = module.private-bucket.id
  }

  targets {
    key = "tag:Managed"
    values = ["true"]
  }
}

module "ec2" {
  source = "../amzn_linux2_instance"
  instance-type = "t3.micro"
  name = "demo-instance"
  security-group-ids = [aws_security_group.instance-sg.id]
  subnet-id = data.aws_subnets.default.ids[0]
  user-data = file("${path.module}/init.sh")
  managed-policy-arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
  tags = {
    Managed: "true"
  }
}