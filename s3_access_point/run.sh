#!/bin/bash

export AWS_PAGER=""

function package() {
  pushd lambda || exit
  rm -f dist/lambda.zip
  yarn install
  yarn build
  zip -j dist/lambda.zip dist/index.js
  zip -r dist/lambda.zip node_modules
  popd || exit
}

function deploy() {
  package
  terraform init && terraform apply -auto-approve
}

function destroy() {
  terraform destroy -auto-approve
}

function invoke_ap_put() {
  if (( "$#" != 3 )); then
    echo "Provide path and payload"
    exit 255
  fi
  aws lambda invoke \
    --function-name "demo-lambda" \
    --payload "{\"endpoint\": \"AP\", \"path\": \"$2\", \"action\": \"PUT\", \"payload\": \"$3\"}" \
    --cli-binary-format raw-in-base64-out \
    /dev/stdout
}

function invoke_ap_get() {
  if (( "$#" != 2 )); then
    echo "Provide path"
    exit 255
  fi
  aws lambda invoke \
    --function-name "demo-lambda" \
    --payload "{\"endpoint\": \"AP\", \"path\": \"$2\", \"action\": \"GET\"}" \
    --cli-binary-format raw-in-base64-out \
    /dev/stdout
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "package") package ;;
  "invoke-ap-put") invoke_ap_put "$@" ;;
  "invoke-ap-get") invoke_ap_get "$@" ;;
esac