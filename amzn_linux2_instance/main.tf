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
  managed_policy_arns = var.managed-policy-arns
}

resource "aws_iam_instance_profile" "instance-profile" {
  role = aws_iam_role.instance-role.id
}

resource "aws_instance" "demo-instance" {
  ami = data.aws_ami.amazon-linux-2.id
  instance_type = var.instance-type
  iam_instance_profile = aws_iam_instance_profile.instance-profile.id
  vpc_security_group_ids = var.security-group-ids
  subnet_id = var.subnet-id
  user_data = var.user-data
  monitoring = var.detailed-monitoring
  tags = merge({
    Name: var.name
  }, var.tags)
}

resource "aws_eip" "eip" {
  count = var.eip ? 1 : 0
  vpc = true
  instance = aws_instance.demo-instance.id
}