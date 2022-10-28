function deploy() {
  terraform init && terraform apply -auto-approve
}

function destroy() {
  terraform destroy -auto-approve
}

function plan() {
  terraform plan
}

function put_s3() {
  account_id=$(aws sts get-caller-identity | jq -r '.Account')
  temp_file=$(mktemp)
  epoch_millis=$(date +%s)
  echo "$epoch_millis" >> temp_file
  aws s3 cp "$temp_file" "s3://demo-bucket-eu-west-1-${account_id}"
  rm "$temp_file"
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "plan") plan ;;
  "put_s3") put_s3 ;;
  "start_backup") start_backup ;;
esac