#!/bin/bash

ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')

function deploy() {
    pushd infra || exit
    terraform init && terraform apply -auto-approve
    popd || exit
}

function destroy() {
  pushd infra || exit
  terraform destroy -auto-approve
  popd || exit
}

function test_put() {
  ./gradlew build
  java -jar build/libs/s3_sse_c-all.jar put --table "demo-bucket-key-table" \
    --path "/test/test.txt" \
    --file "${PWD}/test.txt" \
    --bucket "demo-bucket-eu-west-1-${ACCOUNT_ID}"
}

function test_get() {
  ./gradlew build
  java -jar build/libs/s3_sse_c-all.jar get --table "demo-bucket-key-table" \
    --path "/test/test.txt" \
    --bucket "demo-bucket-eu-west-1-${ACCOUNT_ID}"
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "test-put") test_put ;;
  "test-get") test_get ;;
esac