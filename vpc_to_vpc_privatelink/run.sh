#!/bin/bash -e

export AWS_REGION="eu-west-1"
export AWS_PAGER=""

function deploy() {
  tofu init && tofu apply -auto-approve
}

function destroy() {
  tofu destroy -auto-approve
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
esac