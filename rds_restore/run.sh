#!/bin/bash

export AWS_REGION=eu-west-1
export PGPASSWORD="master123!"
export AWS_PAGER=""

function deploy() {
  terraform init && terraform apply -auto-approve
}

function destroy() {
  terraform destroy -auto-approve
}

function endpoint() {
  db_endpoint=$(aws rds describe-db-clusters | jq -r '.DBClusters[0].Endpoint')
}

function cluster_id() {
  db_cluster_id=$(aws rds describe-db-clusters | jq -r .'DBClusters[0].DBClusterIdentifier')
}

function create_table() {
  endpoint
  psql -h "$db_endpoint" -U master -d postgres -a -f create_table.sql
}

function insert_users() {
  endpoint
  psql -h "$db_endpoint" -U master -d postgres -a -f insert_users.sql
}

function fetch_all_users() {
  endpoint
  psql -h "$db_endpoint" -U master -d postgres -c 'SELECT * FROM users'
}

function create_cluster_snapshot() {
  cluster_id
  timestamp=$(date +%s)
  snapshot_id="${db_cluster_id}-${timestamp}"
  aws rds create-db-cluster-snapshot \
    --db-cluster-identifier "$db_cluster_id" \
    --db-cluster-snapshot-identifier "$snapshot_id"
  aws rds wait db-cluster-snapshot-available \
    --db-cluster-identifier "$db_cluster_id" \
    --db-cluster-snapshot-identifier "$snapshot_id"
}

function remove_cluster_snapshots() {
  snapshots=$(aws rds describe-db-cluster-snapshots | jq -r '.DBClusterSnapshots')
  len=$(jq -r length <<< "$snapshots")
  if (( len > 0 )); then
    last=$(( len - 1 ))
    for index in $(seq 0 "$last")
    do
      item=$(jq -r ".[$index]" <<< "$snapshots")
      snapshot_id=$(jq -r '.DBClusterSnapshotIdentifier' <<< "$item")
      aws rds delete-db-cluster-snapshot --db-cluster-snapshot-identifier "$snapshot_id"
    done
  fi
}

function state() {
  terraform state list
}

function help() {
read -r -d '' HELP_STRING << EOM
deploy | create_table | destroy |
create_cluster_snapshot | insert_users |
fetch_all_users | remove_cluster_snapshots | state
EOM
echo "$HELP_STRING"
}

case "$1" in
  "create_table") create_table ;;
  "insert_users") insert_users ;;
  "fetch_all_users") fetch_all_users ;;
  "deploy") deploy ;;
  "destroy") destroy ;;
  "state") state ;;
  "create_cluster_snapshot") create_cluster_snapshot ;;
  "remove_cluster_snapshots") remove_cluster_snapshots ;;
  *) help ;;
esac