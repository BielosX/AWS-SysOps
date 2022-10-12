#!/bin/bash

export AWS_PAGER=""

function deploy() {
  terraform init && terraform apply -auto-approve
}

function destroy() {
  terraform destroy -auto-approve
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

function multivalue() {
  get_dns_server
  for ip_addr in $(dig +short "@${dns_server}" multivalue.szakalaka.com)
  do
    echo "Response from: ${ip_addr}:"
    curl "http://${ip_addr}"
  done
}

function failover() {
  get_dns_server
  ec2_ip=$(dig +short "@${dns_server}" failover.szakalaka.com)
  curl "http://${ec2_ip}"
}

function geolocation() {
  get_dns_server
  ec2_ip=$(dig +short "@${dns_server}" geolocation.szakalaka.com)
  curl "http://${ec2_ip}"
}

function primary_id() {
  primary_instance_id=$(aws --region eu-west-1 ec2 describe-instances \
    --filters Name="tag:Name",Values=demo-instance | jq -r '.Reservations[0].Instances[0].InstanceId')
}

function stop_primary() {
  primary_id
  aws --region eu-west-1 ec2 stop-instances --instance-ids "${primary_instance_id}"
}

function start_primary() {
  primary_id
  aws --region eu-west-1 ec2 start-instances --instance-ids "${primary_instance_id}"
}

function health() {
  checks=$(aws route53 list-health-checks | jq -r '.HealthChecks')
  len=$(jq -r length <<< "$checks")
  if (( len > 0 )); then
    last=$(( len - 1 ))
    for index in $(seq 0 "$last")
    do
      item=$(jq -r ".[$index]" <<< "$checks")
      ip_addr=$(jq -r '.HealthCheckConfig.IPAddress' <<< "$item")
      check_id=$(jq -r '.Id' <<< "$item")
      status=$(aws route53 get-health-check-status --health-check-id "$check_id" \
        | jq -r '.HealthCheckObservations[0].StatusReport.Status')
      echo "IpAddress: ${ip_addr} Status: \"${status}\""
    done
  fi
}

function help() {
read -r -d '' HELP_STRING << EOM
deploy | destroy | simple | latency |
multivalue | failover | stop_primary |
geolocation | start_primary | health
EOM
echo "$HELP_STRING"
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "simple") simple ;;
  "weighted") weighted ;;
  "latency") latency ;;
  "multivalue") multivalue ;;
  "failover") failover ;;
  "geolocation") geolocation ;;
  "stop_primary") stop_primary ;;
  "start_primary") start_primary ;;
  "health") health ;;
  *) help ;;
esac