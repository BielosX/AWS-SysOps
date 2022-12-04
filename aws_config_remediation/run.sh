#!/bin/bash

export AWS_PAGER=""

SG_NAME="demo-sg"

if [ "$EMAIL" = "" ]; then
  echo "Environment variable EMAIL should be set."
  exit 255
fi

function deploy() {
  terraform init && terraform apply -var="email=${EMAIL}" -auto-approve
}

function destroy() {
  terraform destroy -var="email=${EMAIL}" -auto-approve
}

function create_security_group() {
  aws ec2 create-security-group --group-name "$SG_NAME" --description "Demo SG"
  group_id=$(aws ec2 describe-security-groups --group-names "$SG_NAME" | jq -r '.SecurityGroups[0].GroupId')
read -r -d '' ip_permissions << EOM
[
  {
    "FromPort": 22,
    "ToPort": 22,
    "IpProtocol": "tcp",
    "IpRanges": [
      {
        "CidrIp": "0.0.0.0/0",
        "Description": "All allowed"
      }
     ]
  }
]
EOM
  aws ec2 authorize-security-group-ingress --group-id "$group_id" \
    --ip-permissions "$ip_permissions"
}

function delete_security_group() {
  group_id=$(aws ec2 describe-security-groups --group-names "$SG_NAME" | jq -r '.SecurityGroups[0].GroupId')
  aws ec2 delete-security-group --group-id "$group_id"
}

function remediation_status() {
  aws configservice describe-remediation-execution-status \
       --config-rule-name restricted-ssh
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "create-sg") create_security_group ;;
  "delete-sg") delete_security_group ;;
  "remediation-status") remediation_status ;;
esac