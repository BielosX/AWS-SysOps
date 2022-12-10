#!/bin/bash

export AWS_PAGER=""

function deploy() {
  terraform init && terraform apply -auto-approve
}

function destroy() {
    terraform destroy -auto-approve
}

function test_start() {
  rule_arn=$(aws events describe-rule --name "instances-start-schedule" | jq -r '.Arn')
read -r -d '' payload << EOM
{
  "version": "0",
  "id": "e4fdb2c4-8e6c-9708-3547-c44eaa242197",
  "detail-type": "Scheduled Event",
  "source": "aws.events",
  "account": "536084515174",
  "time": "2022-12-10T22:25:20Z",
  "region": "eu-west-1",
  "resources": [
    "$rule_arn"
  ],
  "detail": {}
}
EOM

tmp_file=$(mktemp)
aws lambda invoke --function-name "mgmt-lambda" --payload "$(echo "$payload" | base64)" "$tmp_file"
cat "$tmp_file"
rm "$tmp_file"
}

function test_stop() {
  rule_arn=$(aws events describe-rule --name "instances-stop-schedule" | jq -r '.Arn')
read -r -d '' payload << EOM
{
  "version": "0",
  "id": "8192c085-2724-7732-7a78-8fe20422892e",
  "detail-type": "Scheduled Event",
  "source": "aws.events",
  "account": "536084515174",
  "time": "2022-12-10T22:22:54Z",
  "region": "eu-west-1",
  "resources": [
    "$rule_arn"
  ],
  "detail": {}
}
EOM

tmp_file=$(mktemp)
aws lambda invoke --function-name "mgmt-lambda" --payload "$(echo "$payload" | base64)" "$tmp_file"
cat "$tmp_file"
rm "$tmp_file"
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "test-start") test_start ;;
  "test-stop") test_stop ;;
esac