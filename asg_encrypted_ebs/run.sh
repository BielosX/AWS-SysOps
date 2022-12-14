#!/bin/bash

export AWS_PAGER=""
account_id=$(aws sts get-caller-identity | jq -r '.Account')
export CDK_DEFAULT_ACCOUNT="$account_id"
export CDK_DEFAULT_REGION="eu-west-1"

function synth() {
  npm run build && cdk synth
}

function kms_stack_create() {
  service_role=$(aws iam get-role --role-name AWSServiceRoleForAutoScaling_EncryptedEbs 2> /dev/null)
  role_arn=""
  if [ "$service_role" = "" ]; then
    role_arn=$(aws iam create-service-linked-role \
      --aws-service-name autoscaling.amazonaws.com \
      --custom-suffix EncryptedEbs | jq -r '.Role.Arn')
  else
    role_arn=$(jq -r '.Role.Arn' <<< "$service_role")
  fi
  sleep 20
  aws cloudformation deploy --template-file kms.yaml \
    --stack-name "ebs-kms-key" \
    --parameter-overrides "AsgServiceLinkedRoleArn=${role_arn}"
}

function kms_stack_destroy() {
  aws cloudformation delete-stack --stack-name "ebs-kms-key"
  aws cloudformation wait stack-delete-complete --stack-name "ebs-kms-key"
}

remove_images() {
  images=$(aws ec2 describe-images --filters "Name=tag:Name,Values=encrypted-demo-app-image")
  for k in $(echo "$images" | jq -r '.Images | keys | .[]'); do
    image=$(echo "$images" | jq -r ".Images[$k]")
    image_id=$(echo "$image" | jq -r '.ImageId')
    mapping_keys=$(echo "$image" | jq -r '.BlockDeviceMappings | keys | .[]')
    snapshot_ids=$(echo "$image" | jq -r '.BlockDeviceMappings | map(.Ebs.SnapshotId)')
    echo "Deleting AMI $image_id"
    aws ec2 deregister-image --image-id "$image_id"
    for id in $mapping_keys; do
      snapshot_id=$(echo "$snapshot_ids" | jq -r ".[$id]")
      echo "Deleting snapshot $snapshot_id"
      aws ec2 delete-snapshot --snapshot-id "$snapshot_id"
    done
  done
}

function image() {
  pushd image || exit
  packer build .
  popd || exit
}

function deploy_cdk() {
  npm run build || exit
  npm run cdk bootstrap || exit
  npm run cdk deploy || exit
}

function destroy_cdk() {
  yes | npm run cdk destroy
}

function deploy() {
  kms_stack_create
  if [ "$2" != "skipImage" ]; then
    image
  fi
  deploy_cdk
}

function destroy() {
  destroy_cdk
  remove_images
  kms_stack_destroy
}

case "$1" in
  "synth") synth ;;
  "deploy-cdk") deploy_cdk ;;
  "destroy-cdk") destroy_cdk ;;
  "image") image ;;
  "kms-stack-create") kms_stack_create ;;
  "kms-stack-destroy") kms_stack_destroy ;;
  "remove-images") remove_images ;;
  "deploy") deploy "$@" ;;
  "destroy") destroy ;;
  *) ;;
esac
