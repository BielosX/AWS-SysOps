#!/bin/bash

export AWS_REGION="eu-west-1"
export AWS_PAGER=""

function deploy() {
  terraform init && terraform apply -auto-approve
}

function destroy() {
  terraform destroy -auto-approve
}

function notify_custom_bus() {
read -r -d '' payload << EOM
[
  {
    "Source": "custom",
    "DetailType": "Test Custom Notification",
    "EventBusName": "custom-bus",
    "Detail": "{\"message\": \"Hello World\"}"
  },
  {
    "Source": "custom-two",
    "DetailType": "Test Custom Notification Two",
    "EventBusName": "custom-bus",
    "Detail": "{\"message\": \"Hello\"}"
  }
]
EOM
  aws events put-events --entries "$payload"
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "notify-custom-bus") notify_custom_bus ;;
esac
