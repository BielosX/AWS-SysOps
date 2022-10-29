#!/bin/bash

export AWS_PAGER=""
export TERM=vt100

function deploy() {
  terraform init && terraform apply -auto-approve
}

function destroy() {
  terraform destroy -auto-approve
}

function create_tunnel() {
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
  cluster_endpoint=$(aws rds describe-db-clusters \
    --db-cluster-identifier aurora-cluster | jq -r '.DBClusters[0].Endpoint')
  ssh -y -o "IdentitiesOnly=yes" -i temp-key "ec2-user@${public_ip}" -L "5432:${cluster_endpoint}:5432"
  rm -f temp-key
  rm -f temp-key.pub
}

function migrate() {
  password=$(aws ssm get-parameter \
    --name "aurora-master-password" \
    --with-decryption | jq -r '.Parameter.Value')
  export FLYWAY_URL="jdbc:postgresql://localhost:5432/postgres"
  export FLYWAY_USER="master"
  export FLYWAY_PASSWORD="$password"
  flyway migrate
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "create-tunnel") create_tunnel ;;
  "migrate") migrate ;;
esac
