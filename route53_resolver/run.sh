#!/bin/bash

export AWS_PAGER=""

function deploy() {
  terraform init && terraform apply -auto-approve
}

function destroy() {
  terraform destroy -auto-approve
}

function ssh_jump_box() {
  instance=$(aws ec2 describe-instances \
    --filters 'Name="tag:Name",Values="jump-box"' 'Name=instance-state-name,Values="running"' \
     | jq -r '.Reservations[0].Instances[0]')
  instance_id=$(jq -r '.InstanceId' <<< "$instance")
  availability_zone=$(jq -r '.Placement.AvailabilityZone' <<< "$instance")
  public_ip=$(jq -r '.PublicIpAddress' <<< "$instance")
  ssh-keygen -t rsa -f temp-key -q -N ""
  aws ec2-instance-connect send-ssh-public-key \
      --instance-id "$instance_id" \
      --availability-zone "$availability_zone" \
      --instance-os-user ec2-user \
      --ssh-public-key file://temp-key.pub
  ssh -y -o "IdentitiesOnly=yes" -i temp-key "ec2-user@${public_ip}"
  rm -f temp-key.pub
  rm -f temp-key
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "ssh-jump-box") ssh_jump_box ;;
esac