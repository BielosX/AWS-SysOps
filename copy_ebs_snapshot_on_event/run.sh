#!/bin/bash

export AWS_PAGER=""
export AWS_REGION="eu-west-1"
COPY_REGION="us-east-1"

function deploy() {
    terraform init && terraform apply -auto-approve
}

function destroy() {
    terraform destroy -auto-approve
}

function snapshot() {
  volume_id=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=demo" \
    | jq -r '.Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId')
    aws ec2 create-snapshot --volume-id "$volume_id" \
      --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=demo-snapshot}]"
}

function remove_snapshots_in_region() {
  snapshots=$(aws --region "$1" ec2 describe-snapshots --filters "Name=tag:Name,Values=demo-snapshot" \
    | jq -r '.Snapshots | map(.SnapshotId) | .[]')
  for snapshot in $snapshots; do
    echo "Deleting snapshot $snapshot"
    aws --region "$1" ec2 delete-snapshot --snapshot-id "$snapshot"
  done
}

function remove_snapshots() {
  remove_snapshots_in_region "$AWS_REGION"
  remove_snapshots_in_region "$COPY_REGION"
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "snapshot") snapshot ;;
  "remove-snapshots") remove_snapshots ;;
esac