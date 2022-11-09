#!/bin/bash

function package() {
  pushd lambda || exit
  rm -f dist/lambda.zip
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

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "package") package ;;
esac