#!/bin/bash

export AWS_PAGER=""

function deploy() {
  terraform init && terraform apply -auto-approve
}

function destroy() {
  terraform destroy -auto-approve
}

function stress() {
  template_id=$(aws ssm get-parameter --name "experiment-template-id" | jq -r '.Parameter.Value')
  aws fis start-experiment --experiment-template-id "$template_id"
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "stress") stress ;;
esac