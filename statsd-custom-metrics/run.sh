#!/bin/bash

export AWS_REGION="eu-west-1"
export AWS_PAGER=""

function package() {
  pushd app || exit
  ./gradlew build
  rm -f app.zip
  zip app.zip appspec.yml
  zip -u app.zip app.service
  zip -j -u app.zip build/libs/app.jar
  zip -r9 app.zip scripts
  popd || exit
}

function deploy() {
  terraform init && terraform apply -auto-approve
}

function destroy() {
  terraform destroy -auto-approve
}

function deploy_app() {
  account_id=$(aws sts get-caller-identity | jq -r '.Account')
  bucket="statsd-demo-${AWS_REGION}-${account_id}"
  package
  aws s3 cp app/app.zip "s3://${bucket}/app.zip"

read -r -d '' revision << EOM
{
  "revisionType": "S3",
  "s3Location": {
    "bucket": "${bucket}",
    "key": "app.zip",
    "bundleType": "zip"
  }
}
EOM

  aws deploy create-deployment \
    --application-name "demo-app" \
    --deployment-group-name "demo-app-deployment-group" \
    --revision "$revision"
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "package") package ;;
  "deploy-app") deploy_app ;;
esac