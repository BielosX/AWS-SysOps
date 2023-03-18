provider "aws" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public-subnets" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.default.id]
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

resource "aws_launch_template" "launch-template" {
  instance_type = "t3.nano"
  image_id = data.aws_ami.amazon-linux-2.id
}

resource "aws_autoscaling_group" "asg" {
  name = "hooks-demo-asg"
  max_size = 4
  min_size = 2
  vpc_zone_identifier = data.aws_subnets.public-subnets.ids
  launch_template {
    id = aws_launch_template.launch-template.id
    version = aws_launch_template.launch-template.latest_version
  }
}

resource "aws_sns_topic" "ec2-terminating-notification" {
  name = "ec2-terminating-notification"
}

data "aws_iam_policy_document" "hook-assume-role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["autoscaling.amazonaws.com"]
      type = "Service"
    }
  }
}

data "aws_iam_policy_document" "hook-role-policy" {
  statement {
    effect = "Allow"
    actions = ["sns:Publish"]
    resources = [aws_sns_topic.ec2-terminating-notification.arn]
  }
}

resource "aws_iam_role" "hook-role" {
  assume_role_policy = data.aws_iam_policy_document.hook-assume-role.json
  inline_policy {
    name = "hook-role-policy"
    policy = data.aws_iam_policy_document.hook-role-policy.json
  }
}

resource "aws_autoscaling_lifecycle_hook" "terminate-hook" {
  name = "notify-on-terminate"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  lifecycle_transition  = "autoscaling:EC2_INSTANCE_TERMINATING"
  default_result = "CONTINUE"
  heartbeat_timeout = 60 * 10
  notification_target_arn = aws_sns_topic.ec2-terminating-notification.arn
  role_arn = aws_iam_role.hook-role.arn
}

resource "aws_autoscaling_lifecycle_hook" "launch-hook" {
  name = "notify-on-launch"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  lifecycle_transition  = "autoscaling:EC2_INSTANCE_LAUNCHING"
  default_result = "ABANDON"
  heartbeat_timeout = 60 * 5
}

resource "aws_cloudwatch_event_rule" "on-ec2-start" {
  name = "on-ec2-start"
  event_pattern = jsonencode({
    "source": [ "aws.autoscaling" ],
    "detail-type": [ "EC2 Instance-launch Lifecycle Action" ],
    "detail": {
      "AutoScalingGroupName": [aws_autoscaling_group.asg.name]
    }
  })
}

module "lambda" {
  source = "../python_lambda"
  function-name = "asg-start-hook-handler"
  handler = "main.handle"
  file-path = "${path.module}/main.py"
  timeout = 60 * 5
  managed-policy-arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/AutoScalingFullAccess",
    "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
  ]
}

resource "aws_lambda_permission" "invoke-permission" {
  action = "lambda:InvokeFunction"
  function_name = module.lambda.function-name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.on-ec2-start.arn
}

resource "aws_cloudwatch_event_target" "lambda-target" {
  arn = module.lambda.function-arn
  rule = aws_cloudwatch_event_rule.on-ec2-start.name
}