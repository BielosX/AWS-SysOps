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

resource "aws_security_group" "spot-instance-sg" {
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 22
    to_port = 22
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol  = "tcp"
    from_port = 443
    to_port   = 443
  }
}

resource "aws_cloudwatch_log_group" "spot-instance-log-group" {
  name = "spot-instance-log-group"
}

resource "aws_ssm_parameter" "worker-code" {
  name = "worker-code"
  type = "String"
  value = file("${path.module}/worker.sh")
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

resource "aws_iam_role" "spot-instance-role" {
  assume_role_policy = data.aws_iam_policy_document.ec2-assume-role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchFullAccess",
    "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
  ]
}

resource "aws_iam_instance_profile" "instance-profile" {
  role = aws_iam_role.spot-instance-role.id
}

resource "aws_launch_template" "spot-instance-launch-template" {
  name = "spot-instance-launch-template"
  instance_type = "t3.medium"
  image_id = data.aws_ami.amazon-linux-2.id
  vpc_security_group_ids = [aws_security_group.spot-instance-sg.id]
  user_data = base64encode(file("${path.module}/init.sh"))
  iam_instance_profile {
    arn = aws_iam_instance_profile.instance-profile.arn
  }
}

data "aws_iam_policy_document" "spot-fleet-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["spotfleet.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "spot-fleet-role" {
  name = "spot-fleet-role"
  assume_role_policy = data.aws_iam_policy_document.spot-fleet-assume-role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2FullAccess"]
}