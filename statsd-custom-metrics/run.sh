#!/bin/bash

export AWS_REGION="eu-west-1"

function deploy() {
  terraform init && terraform apply -auto-approve
}

function destroy() {
  terraform destroy -auto-approve
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
esac