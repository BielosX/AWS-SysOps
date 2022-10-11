terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 2.7.0"
      configuration_aliases = [aws]
    }
  }
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
}

resource "aws_iam_instance_profile" "instance-profile" {
  role = aws_iam_role.instance-role.id
}

resource "aws_security_group" "instance-sg" {
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 80
    to_port = 80
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol  = "tcp"
    from_port = 443
    to_port   = 443
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_instance" "demo-instance" {
  ami = data.aws_ami.amazon-linux-2.id
  instance_type = "t3.micro"
  availability_zone = data.aws_availability_zones.available.names[0]
  vpc_security_group_ids = [aws_security_group.instance-sg.id]
  iam_instance_profile = aws_iam_instance_profile.instance-profile.id
  user_data_base64 = base64encode(file("${path.module}/init.sh"))
  user_data_replace_on_change = true
  tags = {
    Name: "demo-instance"
  }
}