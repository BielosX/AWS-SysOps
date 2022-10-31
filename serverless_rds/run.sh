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
}

function create_db_tunnel() {
  create_tunnel
  cluster_endpoint=$(aws rds describe-db-clusters \
    --db-cluster-identifier aurora-cluster | jq -r '.DBClusters[0].Endpoint')
  ssh -y -o "IdentitiesOnly=yes" -i temp-key "ec2-user@${public_ip}" -L "5432:${cluster_endpoint}:5432"
  rm -f temp-key
  rm -f temp-key.pub
}

function create_proxy_tunnel() {
  create_tunnel
  proxy_endpoint=$(aws rds describe-db-proxies --db-proxy-name aurora-proxy | jq -r '.DBProxies[0].Endpoint')
  ssh -y -o "IdentitiesOnly=yes" -i temp-key "ec2-user@${public_ip}" -L "5432:${proxy_endpoint}:5432"
  rm -f temp-key
  rm -f temp-key.pub
}

function get_proxy_token() {
  proxy_endpoint=$(aws rds describe-db-proxies --db-proxy-name aurora-proxy | jq -r '.DBProxies[0].Endpoint')
  aws rds generate-db-auth-token --hostname "$proxy_endpoint" --port 5432 --username "proxy_user"
}

function migrate() {
  password=$(aws ssm get-parameter \
    --name "aurora-master-password" \
    --with-decryption | jq -r '.Parameter.Value')
  proxy_password=$(aws secretsmanager get-secret-value \
                       --secret-id "proxy-password" \
                       | jq -r '.SecretString | fromjson | .password')
  export FLYWAY_PLACEHOLDERS_PROXY_PASSWORD="$proxy_password"
  export FLYWAY_URL="jdbc:postgresql://localhost:5432/postgres"
  export FLYWAY_USER="master"
  export FLYWAY_PASSWORD="$password"
  flyway migrate
}


function get_all_users() {
  lambda_payload='{"action": "SELECT", "db": "AURORA"}'
  run_lambda
}

function insert_user() {
  lambda_payload='{"action": "INSERT", "db": "AURORA"}'
  run_lambda
}

function get_all_users_proxy() {
  lambda_payload='{"action": "SELECT", "db": "PROXY"}'
  run_lambda
}

function insert_user_proxy() {
  lambda_payload='{"action": "INSERT", "db": "PROXY"}'
  run_lambda
}

function run_lambda() {
  temp_file=$(mktemp)
  aws lambda invoke --function-name "demo-lambda" \
    --payload "$lambda_payload" \
    "$temp_file" \
    --cli-binary-format raw-in-base64-out
  cat "$temp_file"
  rm -f "$temp_file"
}

function package() {
  rm -f lambda.zip
  zip -j lambda.zip src/main.py
  wget -O "proxy_certificate.pem" https://www.amazontrust.com/repository/AmazonRootCA1.pem
  wget -O "db_certificate.pem" https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
  zip -u lambda.zip proxy_certificate.pem
  zip -u lambda.zip db_certificate.pem
  mkdir target
  pushd target || exit
  pip3 download pg8000
  unzip -- \*.whl
  rm -- *.whl
  zip -u -r ../lambda.zip -- *
  popd || exit
  rm -r target
}

function assume_lambda_role() {
  role_arn=$(aws iam get-role --role-name "demo-lambda-role" | jq -r '.Role.Arn')
  credentials=$(aws sts assume-role --role-arn "$role_arn" --role-session-name "demo-lambda-role")
  access_key=$(jq -r '.AccessKeyId' <<< "$credentials")
  secret_key=$(jq -r '.SecretAccessKey' <<< "$credentials")
  session_token=$(jq -r '.SessionToken' <<< "$credentials")
  export AWS_ACCESS_KEY_ID="$access_key"
  export AWS_SECRET_ACCESS_KEY="$secret_key"
  export AWS_SESSION_TOKEN="$session_token"
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "create-db-tunnel") create_db_tunnel ;;
  "create-proxy-tunnel") create_proxy_tunnel ;;
  "proxy-token") get_proxy_token ;;
  "migrate") migrate ;;
  "get-all-users") get_all_users ;;
  "insert-user") insert_user ;;
  "get-all-users-proxy") get_all_users_proxy ;;
  "insert-user-proxy") insert_user_proxy ;;
  "assume-lambda-role") assume_lambda_role ;;
  "package") package ;;
esac
