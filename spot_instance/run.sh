#!/bin/bash

export AWS_REGION="eu-west-1"
export AWS_PAGER=""

function deploy() {
  terraform init && terraform apply -auto-approve
}

function destroy() {
  terraform destroy -auto-approve
}

function launch_spot_fleet() {
  to=$(date -u -v "+5M" "+%Y-%m-%dT%H:%M:%SZ")
  from=$(date -u "+%Y-%m-%dT%H:%M:%SZ")
  echo "From ${from} UTC to ${to} UTC"
  account_id=$(aws sts get-caller-identity | jq -r '.Account')
read -r -d '' request << EOM
{
  "TargetCapacity": 1,
  "ValidUntil": "${to}",
  "IamFleetRole": "arn:aws:iam::${account_id}:role/spot-fleet-role",
  "InstanceInterruptionBehavior": "terminate",
  "TerminateInstancesWithExpiration": true,
  "SpotMaintenanceStrategies": {
    "CapacityRebalance": {
      "ReplacementStrategy": "launch-before-terminate",
      "TerminationDelay": 120
    }
  },
  "LaunchTemplateConfigs": [
    {
      "LaunchTemplateSpecification": {
        "LaunchTemplateName": "spot-instance-launch-template",
        "Version": "\$Latest"
      }
    }
  ]
}
EOM
  aws ec2 request-spot-fleet --spot-fleet-request-config "$request"
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "launch") launch_spot_fleet ;;
esac