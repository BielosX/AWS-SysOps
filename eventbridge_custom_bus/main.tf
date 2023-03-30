provider "aws" {}

resource "aws_cloudwatch_event_bus" "custom-bus" {
  name = "custom-bus"
}

resource "aws_cloudwatch_log_group" "custom-events-log-group" {
  name = "custom-events-log-group"
  retention_in_days = 1
}

data "aws_iam_policy_document" "events-log-publish-policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutLogEventsBatch"
    ]
    resources = ["*"]
    principals {
      type = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "events-publish-policy" {
  policy_document = data.aws_iam_policy_document.events-log-publish-policy.json
  policy_name = "events-publish-policy"
}

resource "aws_cloudwatch_event_rule" "custom-events-rule" {
  name = "custom-events-rule"
  event_bus_name = aws_cloudwatch_event_bus.custom-bus.name
  event_pattern = jsonencode({
    source: ["custom"],
    detail-type: ["Test Custom Notification"]
  })
}

resource "aws_cloudwatch_event_target" "cloudwatch-log-group-target" {
  arn  = aws_cloudwatch_log_group.custom-events-log-group.arn
  rule = aws_cloudwatch_event_rule.custom-events-rule.name
  event_bus_name = aws_cloudwatch_event_bus.custom-bus.name
  input_transformer {
    input_paths = {
      timestamp: "$.time",
      message: "$.detail.message"
    }
    input_template = <<-EOF
    {
      "timestamp": "<timestamp>",
      "message": "Received notification with message: <message>"
    }
    EOF
  }
}