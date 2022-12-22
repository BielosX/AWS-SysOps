import boto3
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

rds_client = boto3.client('rds')

DB_CLUSTER_ID = os.environ['DB_CLUSTER_ID']


def create_secret(service_client, arn, token):
    service_client.get_secret_value(SecretId=arn, VersionStage="AWSCURRENT")

    try:
        service_client.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")
        logger.info(f"createSecret: Successfully retrieved secret for {arn}.")
    except service_client.exceptions.ResourceNotFoundException:
        exclude_characters = os.environ['EXCLUDE_CHARACTERS'] if 'EXCLUDE_CHARACTERS' in os.environ else '/@"\'\\'
        exclude_punctuation = (os.environ['EXCLUDE_PUNCTUATION'] == "True") if 'EXCLUDE_PUNCTUATION' in os.environ else False
        passwd = service_client.get_random_password(ExcludeCharacters=exclude_characters, ExcludePunctuation=exclude_punctuation)

        service_client.put_secret_value(SecretId=arn, ClientRequestToken=token, SecretString=passwd['RandomPassword'],
                                        VersionStages=['AWSPENDING'])
        logger.info(f"createSecret: Successfully put secret for ARN {arn} and version {token}.")


def set_secret(service_client, arn, token):
    secret = service_client.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")
    plaintext = secret['SecretString']
    rds_client.modify_db_cluster(
        DBClusterIdentifier=DB_CLUSTER_ID,
        MasterUserPassword=plaintext
    )


def test_secret(service_client, arn, token):
    logger.info(f"Testing secret {arn} token {token}.")


def finish_secret(service_client, arn, token):
    metadata = service_client.describe_secret(SecretId=arn)
    current_version = None
    for version in metadata["VersionIdsToStages"]:
        if "AWSCURRENT" in metadata["VersionIdsToStages"][version]:
            if version == token:
                logger.info(f"finishSecret: Version {version} already marked as AWSCURRENT for {arn}")
                return
            current_version = version
            break

    service_client.update_secret_version_stage(SecretId=arn, VersionStage="AWSCURRENT", MoveToVersionId=token,
                                               RemoveFromVersionId=current_version)
    logger.info(f"finishSecret: Successfully set AWSCURRENT stage to version {token} for secret {arn}.")


actions = {
    'createSecret': create_secret,
    'setSecret': set_secret,
    'testSecret': test_secret,
    'finishSecret': finish_secret
}


def handler(event, context):
    arn = event['SecretId']
    token = event['ClientRequestToken']
    step = event['Step']

    service_client = boto3.client('secretsmanager')

    metadata = service_client.describe_secret(SecretId=arn)
    if not metadata['RotationEnabled']:
        error = f"Secret {arn} is not enabled for rotation"
        logger.error(error)
        raise ValueError(error)
    versions = metadata['VersionIdsToStages']
    if token not in versions:
        error = f"Secret version {token} has no stage for rotation of secret {arn}."
        logger.error(error)
        raise ValueError(error)
    if "AWSCURRENT" in versions[token]:
        logger.info(f"Secret version {token} already set as AWSCURRENT for secret {token}.")
        return
    elif "AWSPENDING" not in versions[token]:
        error = f"Secret version {token} not set as AWSPENDING for rotation of secret {arn}."
        logger.error(error)
        raise ValueError(error)

    action = actions.get(step)

    if action is None:
        raise ValueError("Invalid step parameter")
    else:
        action(service_client, arn, token)
