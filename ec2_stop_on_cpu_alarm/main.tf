provider "aws" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name  = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name
}

resource "aws_iam_service_linked_role" "events-role" {
  aws_service_name = "events.amazonaws.com"
}

resource "aws_security_group" "demo-sg" {
  vpc_id = data.aws_vpc.default.id
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

module "ec2" {
  source = "../amzn_linux2_instance"
  instance-type = "t3.nano"
  name = "demo-instance"
  security-group-ids = [aws_security_group.demo-sg.id]
  subnet-id = data.aws_subnets.default.ids[0]
  detailed-monitoring = true
  managed-policy-arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}

resource "aws_cloudwatch_metric_alarm" "high-cpu-alarm" {
  alarm_name = "demo-instance-high-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  period = 60
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  statistic = "Average"
  threshold = 50
  dimensions = {
    InstanceId = module.ec2.instance-id
  }
  alarm_actions = ["arn:aws:automate:${local.region}:ec2:stop"] // reboot, terminate, hibernate also possible
}

data "aws_iam_policy_document" "fis-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["fis.amazonaws.com"]
      type = "Service"
    }
  }
}

data "aws_iam_policy_document" "fis-policy" {
  version = "2012-10-17"
  statement {
    sid = "AllowFISExperimentRoleSSMSendCommand"
    effect = "Allow"
    actions = [
      "ssm:SendCommand"
    ]
    resources = [
      "arn:aws:ec2:*:*:instance/*",
      "arn:aws:ssm:*:*:document/*"
    ]
  }
}

resource "aws_iam_role" "fis-role" {
  assume_role_policy = data.aws_iam_policy_document.fis-assume-role.json
  inline_policy {
    name = "fis-ssm-policy"
    policy = data.aws_iam_policy_document.fis-policy.json
  }
}

resource "aws_fis_experiment_template" "cpu-stress" {
  description = "CPS Stress Test"
  role_arn = aws_iam_role.fis-role.arn
  stop_condition {
    source = "none"
  }
  action {
    name = "cpu-stress"
    action_id = "aws:ssm:send-command"
    parameter {
      key = "documentArn"
      value = "arn:aws:ssm:${local.region}::document/AWSFIS-Run-CPU-Stress"
    }
    parameter {
      key = "documentParameters"
      value = jsonencode({
        DurationSeconds: 240
      })
    }
    parameter {
      key = "duration"
      value = "PT5M"
    }
    target {
      key = "Instances"
      value = "demo-instance"
    }
  }

  target {
    name = "demo-instance"
    resource_type  = "aws:ec2:instance"
    selection_mode = "COUNT(1)"

    resource_arns = [module.ec2.instance-arn]
  }
}

resource "aws_ssm_parameter" "experiment-template-id" {
  name  = "experiment-template-id"
  type = "String"
  value = aws_fis_experiment_template.cpu-stress.id
}