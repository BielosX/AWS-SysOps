export AWS_REGION="eu-west-1"
ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')
export CDK_DEFAULT_REGION="$AWS_REGION"
export CDK_DEFAULT_ACCOUNT="$ACCOUNT_ID"
export AWS_PAGER=""

function deploy() {
  ./gradlew clean build shadow spotlessCheck
  jar_file=$(readlink -f build/libs/cloud-watch-logs-processing-lambda-all.jar)
  echo "$jar_file"
  pushd infra || exit
  cdk bootstrap -c "jarPath=$jar_file" || exit
  cdk deploy --all \
    --require-approval never \
    -c "jarPath=$jar_file" || exit
  popd || exit
}

function destroy() {
  temp_path=$(mktemp -d)
  pushd infra || exit
  cdk destroy --all \
    -c "jarPath=$temp_path" || exit
  popd || exit
  rm -rf "$temp_path"
}

function create_log_events() {
  stream_name=$(uuidgen)
  aws logs create-log-stream \
    --log-group-name "demo-log-group" \
    --log-stream-name "$stream_name"
  timestamp=$(python3 -c 'import time; print(int(time.time() * 1000))')
read -r -d '' events << EOM
[
  {
    "timestamp": $timestamp,
    "message": "Test1"
  },
  {
    "timestamp": $timestamp,
    "message": "Test2"
  }
]
EOM
  aws logs put-log-events \
    --log-group-name "demo-log-group" \
    --log-stream-name "$stream_name" \
    --log-events "$events"
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "create-log-events") create_log_events ;;
esac