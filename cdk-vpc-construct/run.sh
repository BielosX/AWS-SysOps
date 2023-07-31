#!/bin/bash

export AWS_REGION="eu-west-1"
export AWS_PAGER=""
ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')
export CDK_DEFAULT_REGION="$AWS_REGION"
export CDK_DEFAULT_ACCOUNT="$ACCOUNT_ID"

NPX="npx ts-node --prefer-ts-exts"

function deploy_simple_vpc() {
  app="$NPX bin/simple-vpc.ts"
  cdk bootstrap --app "$app" || exit
  cdk deploy --app "$app" \
    --require-approval never || exit
}

function deploy_flow_logs() {
  app="$NPX bin/flow-logs.ts"
  cdk bootstrap --app "$app" || exit
  vpc_id=$(aws cloudformation list-exports \
    | jq -r '.Exports | map(select(.Name == "simple-vpc-id")) | .[0].Value')
  cdk deploy --app "$app" \
    --require-approval never \
    -c "vpcId=${vpc_id}" || exit
}

function deploy() {
  deploy_simple_vpc
  deploy_flow_logs
}

function destroy() {
  app="$NPX bin/flow-logs.ts"
  cdk destroy --app "$app" \
    -c "vpcId=temp" || exit
  app="$NPX bin/simple-vpc.ts"
  cdk destroy --app "$app" || exit
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
esac