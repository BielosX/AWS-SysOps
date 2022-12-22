#!/bin/bash

export AWS_REGION="eu-west-1"
export AWS_PAGER=""
SECRET_ID="/rds/demo-cluster/master-password"
CLUSTER_ID="demo-cluster"

function deploy() {
    terraform init && terraform apply -auto-approve
}

function get_password() {
  password=$( aws secretsmanager get-secret-value --secret-id "/rds/demo-cluster/master-password" \
    | jq -r '.SecretString')
}

function get_endpoint() {
  endpoint=$(aws rds describe-db-clusters --db-cluster-identifier demo-cluster \
    | jq -r '.DBClusters[0].Endpoint')
}

function db_connect() {
  get_password
  get_endpoint
  psql "postgresql://master:${password}@${endpoint}:5432/postgres"
}

case "$1" in
  "deploy") deploy ;;
  "describe-secret") aws secretsmanager describe-secret --secret-id "$SECRET_ID" ;;
  "rotate-password") aws secretsmanager rotate-secret --secret-id "$SECRET_ID" ;;
  "password")  get_password; echo "$password" ;;
  "endpoint") get_endpoint; echo "$endpoint" ;;
  "db-connect") db_connect ;;
  "destroy") terraform destroy -auto-approve ;;
esac