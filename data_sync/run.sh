#!/bin/bash

function deploy() {
  terraform init && terraform apply -auto-approve
}

function destroy() {
  terraform destroy -auto-approve
}

function instance_ip() {
    aws ec2 describe-instances \
      --filters "Name=tag:Name,Values=demo-instance" \
      | jq -r '.Reservations[0].Instances[0].PublicIpAddress'
}

function sync() {
  task_arn=$(aws datasync list-tasks | jq -r '.Tasks[] | select(.Name=="efs-to-s3") | .TaskArn')
  aws datasync start-task-execution --task-arn "$task_arn"
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "instance-ip") instance_ip ;;
  "sync") sync ;;
esac