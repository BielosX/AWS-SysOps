import boto3
import json
import time

ec2_client = boto3.client('ec2')
asg_client = boto3.client('autoscaling')


def is_healthy(id):
    status = ec2_client.describe_instance_status(InstanceIds=[id])['InstanceStatuses'][0]
    instance_status = status['InstanceStatus']['Status']
    system_status = status['SystemStatus']['Status']
    print(f"InstanceStatus: {instance_status}, SystemStatus: {system_status}")
    return instance_status == 'ok' and system_status == 'ok'


def handle(event, context):
    string_event = json.dumps(event)
    print(f"Received event: {string_event}")
    lifecycle_hook_name = event['detail']['LifecycleHookName']
    asg_name = event['detail']['AutoScalingGroupName']
    action_token = event['detail']['LifecycleActionToken']
    instance_id = event['detail']['EC2InstanceId']
    transition = event['detail']['LifecycleTransition']

    while not is_healthy(instance_id):
        print(f"Instance {instance_id} is not healthy, waiting")
        time.sleep(20)

    print(f"Instance {instance_id} passed health check")

    asg_client.complete_lifecycle_action(
        LifecycleHookName=lifecycle_hook_name,
        AutoScalingGroupName=asg_name,
        LifecycleActionToken=action_token,
        LifecycleActionResult="CONTINUE",
        InstanceId=instance_id
    )
    print(f"Action {transition} completed for instance {instance_id}")
    return "OK"
