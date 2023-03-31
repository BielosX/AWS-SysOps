#!/bin/bash
yum -y update
yum -y install jq wget curl

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

export AWS_REGION="eu-west-1"

aws ssm get-parameter --name "worker-code" | jq -r '.Parameter.Value' > /opt/worker.sh
chmod +x /opt/worker.sh

cat <<EOT >> /usr/lib/systemd/system/worker.service
[Unit]
After=network.target
[Service]
Type=simple
Restart=always
RestartSec=5
ExecStart=/opt/worker.sh
StandardOutput=journal
StandardError=journal
[Install]
WantedBy=multi-user.target
EOT

systemctl enable worker.service
systemctl start worker.service