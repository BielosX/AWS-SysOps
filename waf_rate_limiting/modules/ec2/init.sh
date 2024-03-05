#!/bin/bash

yum update
yum -y install httpd

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)

cat <<EOM >> /var/www/html/index.html
<html>
  <body>
    <h1>Hello from EC2! InstanceId: $INSTANCE_ID</h1>
  </body>
</html>
EOM

systemctl enable httpd
systemctl start httpd