provider "aws" {}

module "vpc" {
  source = "../simple_vpc"
  cidr-block = "10.0.0.0/16"
  name-prefix = "simple"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account-id = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.name
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
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

resource "aws_iam_instance_profile" "instance-profile" {
  role = aws_iam_role.instance-role.id
}

resource "aws_security_group" "lb-sg" {
  vpc_id = module.vpc.vpc-id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol  = "tcp"
    from_port = 80
    to_port  = 80
  }
  egress {
    cidr_blocks = [module.vpc.vpc-cidr-block]
    protocol  = "tcp"
    from_port = 80
    to_port   = 80
  }
}

resource "aws_security_group" "instance-sg" {
  vpc_id = module.vpc.vpc-id
  ingress {
    security_groups = [aws_security_group.lb-sg.id]
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

resource "aws_cloudwatch_log_group" "nginx-access-logs" {
  name = "nginx-access-logs"
}

data "aws_iam_policy_document" "key-policy" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["kms:*"]
    principals {
      identifiers = ["arn:aws:iam::${local.account-id}:root"]
      type = "AWS"
    }
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = ["kms:*"]
    principals {
      identifiers = ["arn:aws:iam::${local.account-id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"]
      type = "AWS"
    }
    resources = ["*"]
  }
}

resource "aws_kms_key" "root-volume-key" {
  deletion_window_in_days = 7
  policy = data.aws_iam_policy_document.key-policy.json
}

resource "aws_launch_template" "demo-launch-template" {
  image_id = data.aws_ami.amazon-linux-2.id
  instance_type = "t3.nano"
  vpc_security_group_ids = [aws_security_group.instance-sg.id]
  user_data = base64encode(templatefile("${path.module}/init.sh.tmpl", {
    log_group_name: aws_cloudwatch_log_group.nginx-access-logs.name
  }))
  iam_instance_profile {
    arn = aws_iam_instance_profile.instance-profile.arn
  }
  // Encrypted root volume required for Hibernated AWS Warm Pool
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      delete_on_termination = true
      volume_size = 8
      encrypted = true
      volume_type = "gp2"
      kms_key_id = aws_kms_key.root-volume-key.arn
    }
  }
}

resource "aws_elb" "classic-load-balancer" {
  subnets = [module.vpc.public-subnet-id]
  internal = false
  security_groups = [aws_security_group.lb-sg.id]
  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    interval = 30
    target = "HTTP:80/health"
    timeout = 3
  }
}

locals {
  filtering-tag = "NightStop"
  filtering-tag-value = "true"
}

resource "aws_autoscaling_group" "demo-asg" {
  name = "demo-asg"
  max_size = 4
  desired_capacity = 2
  min_size = 0
  vpc_zone_identifier = [module.vpc.private-subnet-id]
  load_balancers = [aws_elb.classic-load-balancer.name]
  health_check_type = "ELB"
  launch_template {
    id = aws_launch_template.demo-launch-template.id
    version = "$Latest"
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 99
    }
  }
  warm_pool {
    pool_state = "Hibernated"
    min_size = 1
    max_group_prepared_capacity = 4
    instance_reuse_policy {
      reuse_on_scale_in = true
    }
  }
  tag {
    propagate_at_launch = true
    key = local.filtering-tag
    value = local.filtering-tag-value
  }
}

resource "aws_cloudwatch_event_rule" "instances-start-schedule" {
  name = "instances-start-schedule"
  schedule_expression = "cron(0 8 ? * * *)"
}

resource "aws_cloudwatch_event_rule" "instances-stop-schedule" {
  name = "instances-stop-schedule"
  schedule_expression = "cron(0 18 ? * * *)"
}

module "demo-lambda" {
  source = "../python_lambda"
  environment-variables = {
    START_RULE_ARN: aws_cloudwatch_event_rule.instances-start-schedule.arn,
    STOP_RULE_ARN: aws_cloudwatch_event_rule.instances-stop-schedule.arn,
    FILTERING_TAG: local.filtering-tag,
    FILTERING_TAG_VALUE: local.filtering-tag-value
  }
  file-path = "${path.module}/main.py"
  function-name = "mgmt-lambda"
  handler = "main.handle"
  managed-policy-arns = [
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
}

resource "aws_lambda_permission" "lambda-permission" {
  action = "lambda:InvokeFunction"
  function_name = module.demo-lambda.function-name
  principal = "events.amazonaws.com"
}

resource "aws_cloudwatch_event_target" "instances-start-target" {
  arn  = module.demo-lambda.function-arn
  rule = aws_cloudwatch_event_rule.instances-start-schedule.name
}

resource "aws_cloudwatch_event_target" "instances-stop-target" {
  arn  = module.demo-lambda.function-arn
  rule = aws_cloudwatch_event_rule.instances-stop-schedule.name
}

locals {
  metric-name = "4XXCount"
  metric-namespace = "Nginx"
}

resource "aws_cloudwatch_log_metric_filter" "nginx-access-log-filter" {
  log_group_name = aws_cloudwatch_log_group.nginx-access-logs.name
  name = "4xx-access-log"
  pattern = "[remote_addr, dash, remote_user, timestamp, request, status_code=4*, body_bytes, http_referer, http_user_agent]"
  metric_transformation {
    name = local.metric-name
    namespace = local.metric-namespace
    value = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "too-many-4xx" {
  alarm_name = "too-many-4xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  period = 60
  threshold = "5"
  statistic = "Sum"
  metric_name = local.metric-name
  namespace = local.metric-namespace
}
