#!/bin/bash

export AWS_REGION="eu-west-1"

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)

function log() {
  timestamp=$(date +%s%3N)

  aws logs put-log-events \
    --log-group-name "spot-instance-log-group" \
    --log-stream-name "$INSTANCE_ID" \
    --log-events timestamp="$timestamp",message="$1"
}

function get_action_response_code() {
  TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  CODE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
    -s -o /dev/null -I -w "%{http_code}" \
    http://169.254.169.254/latest/meta-data/spot/instance-action)
  echo "$CODE"
}

function create_log_stream() {
  log_streams=$(aws logs describe-log-streams \
    --log-group-name "spot-instance-log-group" \
    --log-stream-name-prefix "$INSTANCE_ID" | jq -r '.LogStreams | length')
  if ((log_streams > 0)); then
    echo "Log stream $INSTANCE_ID already exists"
  else
    echo "Creating log stream $INSTANCE_ID"
    aws logs create-log-stream --log-group-name "spot-instance-log-group" --log-stream-name "$INSTANCE_ID"
  fi
}

create_log_stream
log "Starting worker"

while true
do
  get_action_response_code
  if [ "$CODE" != "404" ]; then
    log "Instance will be interrupted in 2 minutes"
  else
    log "Instance still running"
  fi
  sleep 5
done