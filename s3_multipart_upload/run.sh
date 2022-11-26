#!/bin/bash

export AWS_PAGER=""
export AWS_REGION="eu-west-1"
ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')
AWS_BUCKET="demo-bucket-${AWS_REGION}-${ACCOUNT_ID}"

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

function upload() {
  ./gradlew build
  temp_file=$(mktemp)
  file_size=$(( 60 * 1000 * 1000 ))
  tr -dc A-Za-z0-9 </dev/urandom | head -c "$file_size" >> "$temp_file"
  java -jar build/libs/s3_multipart_upload-all.jar \
    --bucket "$AWS_BUCKET" \
    --key "test.txt" \
    --file "$temp_file"
  rm -f "$temp_file"
}

function get_content() {
  temp_file=$(mktemp)
  aws s3api get-object --bucket "$SOURCE_BUCKET_NAME" --key "test.txt" "$temp_file" >> /dev/null
  cat "$temp_file"
  rm -f "$temp_file"
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "upload") upload ;;
  "get-content") get_content ;;
esac