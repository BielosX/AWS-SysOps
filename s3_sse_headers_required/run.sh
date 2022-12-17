#!/bin/bash

export AWS_PAGER=""
export AWS_REGION="eu-west-1"
ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')

function test_fail() {
  tmp_file=$(mktemp)
  echo "Hello" >> "$tmp_file"
  aws s3 cp "$tmp_file" "s3://sse-s3-bucket-${AWS_REGION}-${ACCOUNT_ID}/test.txt"
  aws s3 cp "$tmp_file" "s3://sse-kms-bucket-${AWS_REGION}-${ACCOUNT_ID}/test.txt"
  rm "$tmp_file"
}

function test_success() {
  tmp_file=$(mktemp)
  echo "Hello" >> "$tmp_file"
  aws s3 cp "$tmp_file" "s3://sse-s3-bucket-${AWS_REGION}-${ACCOUNT_ID}/test.txt" --sse "AES256"
  aws s3 cp "$tmp_file" "s3://sse-kms-bucket-${AWS_REGION}-${ACCOUNT_ID}/test.txt" --sse "aws:kms" --sse-kms-key-id "alias/demo-key"
  rm "$tmp_file"
}

case "$1" in
  "deploy") terraform init && terraform apply -auto-approve ;;
  "destroy") terraform destroy -auto-approve ;;
  "test-fail") test_fail ;;
  "test-success") test_success ;;
esac