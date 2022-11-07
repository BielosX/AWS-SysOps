export AWS_PAGER=""

function deploy() {
  terraform init && terraform apply -auto-approve
}

function destroy() {
  terraform destroy -auto-approve
}

function curl_target() {
  if (( "$#" != 3 )); then
    echo "Provide source and target"
    exit 255
  fi
  target_private_ip=$(aws ec2 describe-instances \
    --filters "Name='tag:Name',Values=$3-demo-instance" "Name=instance-state-name,Values=running" \
    | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')
  ssm_command=$(aws ssm send-command --document-name "curl-target" \
    --parameters TargetIp="$target_private_ip" \
    --targets "Key='tag:Name',Values=$2-demo-instance" \
      | jq -r '.Command')
  command_id=$(jq -r '.CommandId' <<< "$ssm_command")
  status=$(jq -r '.Status' <<< "$ssm_command")
  while [ "$status" != 'Success' ] && [ "$status" != 'Failed' ]; do
    sleep 5
    ssm_command=$(aws ssm list-command-invocations \
      --command-id "$command_id" \
      | jq -r '.CommandInvocations[0]')
    status=$(jq -r '.Status' <<< "$ssm_command")
  done
  if [ "$status" = 'Failed' ]; then
    echo "Command failed"
    exit 255
  fi
  instance_id=$(jq -r '.InstanceId' <<< "$ssm_command")
  command_out=$(aws ssm get-command-invocation \
    --command-id "$command_id" \
    --instance-id "$instance_id" \
    | jq -r '.StandardOutputContent')
  echo "$command_out"
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "curl") curl_target "$@" ;;
esac