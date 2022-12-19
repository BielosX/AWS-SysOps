#!/bin/bash

export AWS_PAGER=""
export AWS_REGION="eu-west-1"

function stage_url() {
  api_endpoint=$(aws apigatewayv2 get-apis | jq -r '.Items[] | select(.Name=="demo-api") | .ApiEndpoint')
  stage_endpoint="${api_endpoint}/v1"
}

function get() {
  stage_url
  url="${stage_endpoint}/lambda/1234"
  echo "$url"
  curl "$url"
}

case "$1" in
  "deploy") terraform init && terraform apply -auto-approve ;;
  "destroy") terraform destroy -auto-approve ;;
  "get") get ;;
esac