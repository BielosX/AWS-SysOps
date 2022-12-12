import boto3
import os


def handle(event, context):
    target_region = os.environ['TARGET_REGION']
    source_region = os.environ['SOURCE_REGION']
    snapshot_name = os.environ['SNAPSHOT_NAME']
    snapshot_arn = event['detail']['snapshot_id']
    snapshot_id = snapshot_arn.split('/')[1]
    client = boto3.client('ec2', region_name=target_region)
    print(f"copy snapshot {snapshot_id} from {source_region} to {target_region}")
    response = client.copy_snapshot(
        SourceSnapshotId=snapshot_id,
        SourceRegion=source_region,
        TagSpecifications=[
            {
                'ResourceType': 'snapshot',
                'Tags': [
                    {
                        'Key': 'Name',
                        'Value': snapshot_name
                    }
                ]
            }
        ]
    )
    copy_snapshot_id = response['SnapshotId']
    print(f"copy snapshot {copy_snapshot_id}")
    return "OK"
