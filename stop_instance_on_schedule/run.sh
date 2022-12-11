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

function get_desired_capacity() {
  desired_capacity=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "demo-asg" |
    jq -r '.AutoScalingGroups[0].DesiredCapacity')
}

function scale_up() {
  get_desired_capacity
  new_capacity=$(( desired_capacity + 1))
  aws autoscaling set-desired-capacity --auto-scaling-group-name "demo-asg" \
    --desired-capacity "$new_capacity"
}

function scale_down() {
  get_desired_capacity
  new_capacity=$(( desired_capacity - 1))
  aws autoscaling set-desired-capacity --auto-scaling-group-name "demo-asg" \
    --desired-capacity "$new_capacity"
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "test-start") test_start ;;
  "test-stop") test_stop ;;
  "scale-up") scale_up ;;
  "scale-down") scale_down ;;
esac