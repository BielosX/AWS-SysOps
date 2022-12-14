import boto3
import random
import json
import os
import uuid
import time

client = boto3.client('logs')


def handle(event, context):
    log_group = os.environ['LOG_GROUP']
    log_stream = str(uuid.uuid4())
    emails = ["first@acme.com", "second@acme.com"]
    status = ["success", "failed"]
    selected_email = random.randrange(0, 2)
    selected_status = random.randrange(0, 2)
    log_payload = {
        'user': {
            'id': 1,
            'email': emails[selected_email]
        },
        'details': {
            'status': status[selected_status]
        }
    }
    log_string = json.dumps(log_payload)
    timestamp = int(time.time() * 1000)
    client.create_log_stream(
        logGroupName=log_group,
        logStreamName=log_stream
    )
    client.put_log_events(
        logGroupName=log_group,
        logStreamName=log_stream,
        logEvents=[
            {
                'timestamp': timestamp,
                'message': log_string
            }
        ]
    )
    return "OK"
