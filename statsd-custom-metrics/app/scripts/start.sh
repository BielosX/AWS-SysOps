#!/bin/sh

systemctl daemon-reload
systemctl enable app.service
systemctl restart app.service