provider "aws" {}

resource "aws_apigatewayv2_api" "demo-api" {
  name = "demo-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id = aws_apigatewayv2_api.demo-api.id
  name = "v1"
  auto_deploy = true
}

module "lambda" {
  source = "../python_lambda"
  function-name = "demo-function"
  handler = "main.handle"
  code = <<-EOT
  def handle(event, context):
    return "Hello"
  EOT
}

resource "aws_lambda_permission" "invoke-permission" {
  action = "lambda:InvokeFunction"
  function_name = module.lambda.function-name
  principal = "apigateway.amazonaws.com"
}

resource "aws_apigatewayv2_integration" "lambda-integration" {
  api_id = aws_apigatewayv2_api.demo-api.id
  integration_type = "AWS_PROXY"

  connection_type = "INTERNET"
  description = "Lambda integration"
  integration_method = "POST"
  integration_uri = module.lambda.invoke-arn
  passthrough_behavior = "WHEN_NO_MATCH"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "route" {
  api_id = aws_apigatewayv2_api.demo-api.id
  route_key = "ANY /lambda/{proxy+}"

  target = "integrations/${aws_apigatewayv2_integration.lambda-integration.id}"
}