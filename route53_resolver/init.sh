#!/bin/bash

yum -y update
yum -y install httpd

cat <<EOT >> /var/www/html/index.html
<h1>Hello from EC2!</h1>
EOT

systemctl enable httpd
systemctl start httpd
