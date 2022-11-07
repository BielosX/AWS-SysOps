#!/bin/bash

yum -y update
yum -y install httpd
yum -y install jq

TTL_HEADER="X-aws-ec2-metadata-token-ttl-seconds: 21600"
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "$TTL_HEADER")
URL="http://169.254.169.254/latest/dynamic/instance-identity/document"
INSTANCE_IDENTITY=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v "$URL")
INSTANCE_ID=$(jq -r '.instanceId' <<< "$INSTANCE_IDENTITY")
PRIVATE_IP=$(jq -r '.privateIp' <<< "$INSTANCE_IDENTITY")

cat <<EOT >> /var/www/html/index.html
<h1>Hello from EC2!</h1>
<p>InstanceId: ${INSTANCE_ID}</p>
<p>PrivateIp: ${PRIVATE_IP}</p>
EOT

systemctl enable httpd
systemctl start httpd
