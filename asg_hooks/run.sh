#!/bin/bash

export AWS_REGION="eu-west-1"
export AWS_PAGER=""

function subscribe() {
  if [ "$1" == "" ]; then
    echo "Provide email address"
    exit 255
  fi
  account_id=$(aws sts get-caller-identity | jq -r '.Account')
  topic_arn="arn:aws:sns:${AWS_REGION}:${account_id}:ec2-terminating-notification"
  emails=$(aws sns list-subscriptions-by-topic --topic-arn "$topic_arn" | jq -r '.Subscriptions | map(.Endpoint)')
  provided_email=$(jq -r --arg email "$1" '.[] | select(.==$email)' <<< "$emails")
  if [ "$provided_email" != "" ]; then
    echo "Email $1 already subscribed to $topic_arn"
    exit 255
  fi
  aws sns subscribe --topic-arn "$topic_arn" --protocol "email" --notification-endpoint "$1"
}

function remove_all_subscriptions() {
  account_id=$(aws sts get-caller-identity | jq -r '.Account')
  topic_arn="arn:aws:sns:${AWS_REGION}:${account_id}:ec2-terminating-notification"
  subscriptions=$(aws sns list-subscriptions-by-topic --topic-arn "$topic_arn" \
    | jq -r '.Subscriptions | map(.SubscriptionArn)')
  length=$(jq -r 'length' <<< "$subscriptions")
  for ((i=0;i<length;i++)); do
    subscription=$(jq -r ".[$i]" <<< "$subscriptions")
    aws sns unsubscribe --subscription-arn "$subscription"
  done
}

function deploy() {
  terraform init && terraform apply -auto-approve
}

function destroy() {
  remove_all_subscriptions
  terraform destroy -auto-approve
}

function refresh_asg() {
read -r -d '' refresh_config << EOM
{
  "MinHealthyPercentage": 100,
  "InstanceWarmup": 10
}
EOM

  aws autoscaling start-instance-refresh \
    --auto-scaling-group-name "hooks-demo-asg" \
    --strategy "Rolling" \
    --preferences "$refresh_config"
}

function continue_terminate() {
  if [ "$1" == "" ]; then
    echo "InstanceId not provided"
    exit 255
  fi
  aws autoscaling complete-lifecycle-action --lifecycle-action-result CONTINUE \
   --instance-id "$1" --lifecycle-hook-name "notify-on-terminate" \
   --auto-scaling-group-name "hooks-demo-asg"
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "subscribe") subscribe "$2" ;;
  "remove-all-subscriptions") remove_all_subscriptions ;;
  "refresh-asg") refresh_asg ;;
  "continue-terminate") continue_terminate "$2" ;;
esac