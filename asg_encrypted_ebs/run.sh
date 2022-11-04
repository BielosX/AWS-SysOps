#!/bin/bash

export AWS_PAGER=""
account_id=$(aws sts get-caller-identity | jq -r '.Account')
export CDK_DEFAULT_ACCOUNT="$account_id"
export CDK_DEFAULT_REGION="eu-west-1"

function deploy() {
  npm run build || exit
  npm run cdk bootstrap || exit
  npm run cdk deploy || exit
  asg=$(aws autoscaling describe-auto-scaling-groups \
    --filters 'Name="tag:Name",Values="demo-asg"' | jq -r '.AutoScalingGroups[0].AutoScalingGroupName')
  aws autoscaling start-instance-refresh --auto-scaling-group-name "$asg" --strategy "Rolling"
}

function destroy() {
  yes | npm run cdk destroy
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
esac
