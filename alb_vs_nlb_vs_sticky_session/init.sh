#!/bin/bash

yum update
yum -y install nginx

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)

cat <<EOT > /usr/share/nginx/html/index.html
<html>
<body>
<h1>EC2 Metadata</h1>
<p>InstanceId: ${INSTANCE_ID}</p>
<p>AvailabilityZone: ${AZ}</p>
</body>
</html>
EOT

systemctl enable nginx
systemctl start nginx