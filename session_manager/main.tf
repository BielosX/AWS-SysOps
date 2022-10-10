provider "aws" {}

data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name
}

resource "aws_vpc" "demo-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
}

resource "aws_subnet" "private-subnet" {
  vpc_id = aws_vpc.demo-vpc.id
  map_public_ip_on_launch = false
  cidr_block = cidrsubnet(aws_vpc.demo-vpc.cidr_block, 8, 1)
}

resource "aws_security_group" "interface-endpoint-sg" {
  vpc_id = aws_vpc.demo-vpc.id
  ingress {
    cidr_blocks = [aws_vpc.demo-vpc.cidr_block]
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 443
    to_port = 443
    protocol  = "tcp"
  }
}

locals {
  ssm-endpoints = [
    "com.amazonaws.${local.region}.ssm",
    "com.amazonaws.${local.region}.ssmmessages",
    "com.amazonaws.${local.region}.ec2messages"
  ]
}

resource "aws_vpc_endpoint" "ssm-endpoints" {
  count = length(local.ssm-endpoints)
  service_name = local.ssm-endpoints[count.index]
  vpc_id = aws_vpc.demo-vpc.id
  vpc_endpoint_type = "Interface"
  auto_accept = true
  private_dns_enabled = true
  subnet_ids = [aws_subnet.private-subnet.id]
  security_group_ids = [aws_security_group.interface-endpoint-sg.id]
}

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

resource "aws_security_group" "instance-sg" {
  vpc_id = aws_vpc.demo-vpc.id
  ingress {
    security_groups = [aws_security_group.interface-endpoint-sg.id]
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }
  egress {
    security_groups = [aws_security_group.interface-endpoint-sg.id]
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }
}

data "aws_iam_policy_document" "ec2-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "instance-role" {
  assume_role_policy = data.aws_iam_policy_document.ec2-assume-role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

resource "aws_iam_instance_profile" "instance-profile" {
  role = aws_iam_role.instance-role.id
}

resource "aws_instance" "demo-instance" {
  ami = data.aws_ami.amazon-linux-2.id
  instance_type = "t3.micro"
  subnet_id = aws_subnet.private-subnet.id
  vpc_security_group_ids = [aws_security_group.instance-sg.id]
  iam_instance_profile = aws_iam_instance_profile.instance-profile.id
  tags = {
    Name: "session-manager-demo"
  }
}