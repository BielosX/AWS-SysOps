import boto3
import os

ec2 = boto3.client('ec2')
asg = boto3.client('autoscaling')


def handle(event, context):
    stop_rule_arn = os.environ['STOP_RULE_ARN']
    start_rule_arn = os.environ['START_RULE_ARN']
    filtering_tag = os.environ['FILTERING_TAG']
    filtering_tag_value = os.environ['FILTERING_TAG_VALUE']
    caller = event['resources'][0]
    response = ec2.describe_instances(
        Filters=[
            {
                'Name': f'tag:{filtering_tag}',
                'Values': [filtering_tag_value]
            },
            {
                'Name': "instance-state-name",
                'Values': ['running', 'stopped']
            }
        ]
    )
    instances = [instance for reservation in response['Reservations'] for instance in reservation['Instances']]
    for instance in instances:
        instance_id = instance['InstanceId']
        state = instance['State']['Name']
        autoscaling_group = list(map(lambda tag: tag['Value'],
                                filter(lambda tag: tag['Key'] == 'aws:autoscaling:groupName', instance['Tags'])))[0]
        if caller == stop_rule_arn and state == 'running':
            asg.enter_standby(
                InstanceIds=[instance_id],
                AutoScalingGroupName=autoscaling_group,
                ShouldDecrementDesiredCapacity=True
            )
            ec2.stop_instances(
                InstanceIds=[instance_id]
            )
        elif caller == start_rule_arn and state == 'stopped':
            ec2.start_instances(
                InstanceIds=[instance_id]
            )
            asg.exit_standby(
                InstanceIds=[instance_id],
                AutoScalingGroupName=autoscaling_group
            )
    return "OK"
