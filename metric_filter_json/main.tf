provider "aws" {}

resource "aws_cloudwatch_log_group" "demo-log-group" {
  name_prefix = "demo-log-group"
}

module "lambda" {
  source = "../python_lambda"
  environment-variables = {
    LOG_GROUP: aws_cloudwatch_log_group.demo-log-group.name
  }
  file-path = "${path.module}/main.py"
  function-name = "demo-lambda"
  handler = "main.handle"
  managed-policy-arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  ]
}

resource "aws_lambda_permission" "lambda-invoke-permission" {
  action = "lambda:InvokeFunction"
  function_name = module.lambda.function-name
  principal = "events.amazonaws.com"
}

resource "aws_cloudwatch_event_rule" "run-every-minute" {
  name = "run-every-minute"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "lambda-target" {
  arn  = module.lambda.function-arn
  rule = aws_cloudwatch_event_rule.run-every-minute.name
}

locals {
  metric-name = "JsonError"
  metric-namespace = "Demo"
}

resource "aws_cloudwatch_log_metric_filter" "json-log-filter" {
  log_group_name = aws_cloudwatch_log_group.demo-log-group.name
  name = "json-error"
  pattern = "{ ($.user.email = \"first@acme.com\") && ($.details.status = \"failed\") }"
  metric_transformation {
    name = local.metric-name
    namespace = local.metric-namespace
    value = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "too-many-errors" {
  alarm_name = "too-many-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 5
  period = 60
  threshold = "5"
  statistic = "Sum"
  metric_name = local.metric-name
  namespace = local.metric-namespace
}
