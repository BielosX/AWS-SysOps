#!/bin/bash

export AWS_PAGER=""
STACK_NAME="policies-demo"

function deploy() {
  aws cloudformation deploy --template-file infra.yaml --stack-name "$STACK_NAME"
}

function destroy() {
  aws cloudformation delete-stack --stack-name "$STACK_NAME"
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
esac