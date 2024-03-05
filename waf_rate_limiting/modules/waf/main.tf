resource "aws_wafv2_web_acl" "web_acl" {
  name  = "rate-limit"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  custom_response_body {
    key          = "too-many-requests"
    content_type = "TEXT_HTML"
    content      = <<-EOM
    <html>
      <head><title>429 Too Many Requests</title></head>
      <body>
        <center><h1>429 Too Many Requests</h1></center>
      </body>
    </html>
    EOM
  }

  rule {
    name     = "rate-limiting"
    priority = 1
    action {
      block {
        custom_response {
          response_code            = "429"
          custom_response_body_key = "too-many-requests"
        }
      }
    }
    statement {
      rate_based_statement {
        limit              = 100
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limiting-rule"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "rate-limiting"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "alb_association" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.web_acl.arn
}