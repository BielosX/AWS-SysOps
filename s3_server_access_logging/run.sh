#!/bin/bash

export AWS_REGION="eu-west-1"
export AWS_PAGER=""
ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')
SOURCE_BUCKET_NAME="s3-access-logging-source-bucket-${AWS_REGION}-${ACCOUNT_ID}"

function deploy() {
  terraform init && terraform apply -auto-approve
}

function destroy() {
  terraform destroy -auto-approve
}

function put_random_object() {
  object_name="test-${RANDOM}.txt"
  tmp_file=$(mktemp)
  echo "test data ${RANDOM}" >> "$tmp_file"
  aws s3 cp "$tmp_file" "s3://${SOURCE_BUCKET_NAME}/${object_name}"
  rm "$tmp_file"
}

function get_random_object() {
  objects=$(aws s3api list-objects-v2 --bucket "$SOURCE_BUCKET_NAME" | jq -r '.Contents')
  len=$(jq -r 'length' <<< "$objects")
  index=$(( RANDOM % len ))
  item=$(jq -r ".[${index}].Key" <<< "$objects")
  tmp_file=$(mktemp)
  aws s3api get-object --bucket "$SOURCE_BUCKET_NAME" --key "$item" "$tmp_file" >> /dev/null
  cat "$tmp_file"
  rm "$tmp_file"
}

function get_n_random_objects() {
  for _ in $(seq 1 "$1"); do
    get_random_object
  done
}

function put_n_random_objects() {
  for _ in $(seq 1 "$1"); do
    put_random_object
  done
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "put-random-object") put_random_object ;;
  "get-random-object") get_random_object ;;
  "get-n-random-objects") get_n_random_objects "$2" ;;
  "put-n-random-objects") put_n_random_objects "$2" ;;
esac