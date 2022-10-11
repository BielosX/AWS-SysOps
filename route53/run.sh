#!/bin/bash

function deploy() {
  pushd eu-west-1 || exit
  terraform init && terraform apply -auto-approve
  popd || exit
  pushd us-east-1 || exit
  terraform init && terraform apply -auto-approve
  popd || exit
  pushd global || exit
  terraform init && terraform apply -auto-approve
  popd || exit
}

function destroy() {
  pushd global || exit
  terraform destroy -auto-approve || exit
  popd || exit
  pushd eu-west-1 || exit
  terraform destroy -auto-approve || exit
  popd || exit
  pushd us-east-1 || exit
  terraform destroy -auto-approve || exit
  popd || exit
}

function get_hosted_zone_id() {
  zone_id=$(aws route53 list-hosted-zones-by-name --dns-name szakalaka.com | jq -r '.HostedZones[0].Id')
}

function get_dns_server() {
  get_hosted_zone_id
  dns_server=$(aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" \
    | jq -r '.ResourceRecordSets[] | select(.Type == "NS") | .ResourceRecords[0].Value')
}

function simple() {
  get_dns_server
  ec2_ip=$(dig +short "@${dns_server}" simple.szakalaka.com)
  curl "http://${ec2_ip}"
}

function weighted() {
  get_dns_server
  ec2_ip=$(dig +short "@${dns_server}" weighted.szakalaka.com)
  curl "http://${ec2_ip}"
}

function latency() {
  get_dns_server
  ec2_ip=$(dig +short "@${dns_server}" latency.szakalaka.com)
  curl "http://${ec2_ip}"
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "simple") simple ;;
  "weighted") weighted ;;
  "latency") latency ;;
  *) echo "deploy | destroy | simple | latency" ;;
esac