#!/bin/bash

STACK_NAME="cf-scripts-demo"
export AWS_REGION="eu-west-1"
export AWS_PAGER=""

function deploy() {
  aws cloudformation deploy --template-file main.yaml \
    --stack-name "$STACK_NAME"
}

function destroy() {
  aws cloudformation delete-stack --stack-name "$STACK_NAME"
  while aws cloudformation describe-stacks --stack-name "$STACK_NAME" > /dev/null 2>&1
  do
   echo "Stack $STACK_NAME still exists. Destroying"
   sleep 10
  done
  echo "Stack $STACK_NAME removed"
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
esac