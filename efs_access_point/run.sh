#!/bin/bash

function deploy() {
  terraform init && terraform apply -auto-approve
}

function destroy() {
  terraform destroy -auto-approve
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
esac