#!/bin/bash -xe
yum -y update
yum -y install httpd
yum -y install jq

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_IDENTITY=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/dynamic/instance-identity/document)
REGION=$(jq -r '.region' <<< "$INSTANCE_IDENTITY")
INSTANCE_ID=$(jq -r '.instanceId' <<< "$INSTANCE_IDENTITY")
AZ=$(jq -r '.availabilityZone' <<< "$INSTANCE_IDENTITY")
IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/public-ipv4)

cat <<EOT >> /var/www/html/index.html
<h1>Hello from EC2!</h1>
<h3>InstanceId: ${INSTANCE_ID}</h3>
<h3>Region: ${REGION}</h3>
<h3>AvailabilityZone: ${AZ}</h3>
<h3>Public IP: ${IP}</h3>
EOT

systemctl enable httpd
systemctl start httpd