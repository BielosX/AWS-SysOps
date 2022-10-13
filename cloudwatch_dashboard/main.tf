provider "aws" {}

data "aws_region" "current" {}

module "vpc-flow-logs" {
  source = "../vpc_flow_logs"
}

data "archive_file" "lambda-artifact" {
  source_file = "${path.module}/main.py"
  output_path = "${path.module}/lambda.zip"
  type = "zip"
}

data "aws_iam_policy_document" "lambda-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type = "Service"
    }
  }
}

resource "aws_iam_role" "lambda-role" {
  assume_role_policy = data.aws_iam_policy_document.lambda-assume-role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
}

resource "aws_lambda_function" "demo-function" {
  function_name = "demo-function"
  role = aws_iam_role.lambda-role.arn
  handler = "main.handler"
  runtime = "python3.9"
  filename = data.archive_file.lambda-artifact.output_path
  source_code_hash = data.archive_file.lambda-artifact.output_base64sha256
}

resource "aws_cloudwatch_event_rule" "lambda-every-minute" {
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "lambda-target" {
  arn  = aws_lambda_function.demo-function.arn
  rule = aws_cloudwatch_event_rule.lambda-every-minute.name
}

resource "aws_lambda_permission" "allow-events-invoke-lambda" {
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.demo-function.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.lambda-every-minute.arn
}

resource "aws_cloudwatch_log_metric_filter" "error-logs" {
  log_group_name = "/aws/lambda/${aws_lambda_function.demo-function.function_name}"
  name = "LambdaErrorLogs"
  pattern = "ERROR"
  metric_transformation {
    name = "ErrorCount"
    namespace = aws_lambda_function.demo-function.function_name
    value = "1"
    unit = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "error-alarm" {
  alarm_name = "lambda-error-logs-too-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  statistic = "Sum"
  evaluation_periods = 1
  namespace = aws_cloudwatch_log_metric_filter.error-logs.metric_transformation[0].namespace
  metric_name = aws_cloudwatch_log_metric_filter.error-logs.metric_transformation[0].name
  threshold = 2
  period = 300
}

resource "aws_cloudwatch_dashboard" "demo-dashboard" {
  dashboard_body = templatefile("${path.module}/widgets.json", {
    region: data.aws_region.current.name,
    network_interface_log_group: module.vpc-flow-logs.network-interface-flow-log-group-id,
    network_interface_id: module.vpc-flow-logs.network-interface-id,
    vpc_id: module.vpc-flow-logs.vpc-id,
    vpc_log_group: module.vpc-flow-logs.vpc-flow-log-group-id,
    subnet_id: module.vpc-flow-logs.subnet-id,
    subnet_log_group: module.vpc-flow-logs.subnet-flow-log-group-id,
    lambda_errors_namespace: aws_cloudwatch_log_metric_filter.error-logs.metric_transformation[0].namespace,
    lambda_errors_name: aws_cloudwatch_log_metric_filter.error-logs.metric_transformation[0].name,
    lambda_id: aws_lambda_function.demo-function.id,
    error_logs_too_high_arn: aws_cloudwatch_metric_alarm.error-alarm.arn
  })
  dashboard_name = "demo-dashboard"
}
