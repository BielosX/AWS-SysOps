import boto3
import time
import sys

rds_client = boto3.client('rds')


def describe_cluster(cluster_id):
    return rds_client.describe_db_clusters(DBClusterIdentifier=cluster_id)['DBClusters'][0]


def cluster_exists(cluster_id):
    try:
        response = rds_client.describe_db_clusters(DBClusterIdentifier=cluster_id)
        return response['DBClusters'][0]['DBClusterIdentifier'] == cluster_id
    except rds_client.exceptions.DBClusterNotFoundFault:
        return False


def remove_existing_cluster(cluster):
    cluster_instances = cluster['DBClusterMembers']
    for member in cluster_instances:
        instance_id = member['DBInstanceIdentifier']
        rds_client.delete_db_instance(
            DBInstanceIdentifier=instance_id,
            SkipFinalSnapshot=True,
            DeleteAutomatedBackups=False
        )
    cluster_id = cluster['DBClusterIdentifier']
    rds_client.delete_db_cluster(
        DBClusterIdentifier=cluster_id,
        SkipFinalSnapshot=True
    )
    while cluster_exists(cluster_id):
        print("Cluster {} still exists, waiting 30 seconds".format(cluster_id))
        time.sleep(30.0)


def restore_cluster_from_snapshot(cluster_id, subnet_group, snapshot_id):
    response = rds_client.restore_db_cluster_from_snapshot(
        DBClusterIdentifier=cluster_id,
        DBSubnetGroupName=subnet_group,
        SnapshotIdentifier=snapshot_id,
        Engine="aurora-postgresql"
    )
    status = response['DBCluster']['Status']
    while status != 'available':
        print("Cluster {} is being created, current status: {}".format(cluster_id, status))
        time.sleep(30.0)
        status = describe_cluster(cluster_id)['Status']


def restore_cluster(cluster_id, snapshot_id):
    cluster = describe_cluster(cluster_id)
    subnet_group = cluster['DBSubnetGroup']
    remove_existing_cluster(cluster)
    restore_cluster_from_snapshot(cluster_id, subnet_group, snapshot_id)


def main():
    if len(sys.argv) < 3:
        print("Usage: python restore_cluster.py <cluster_id> <snapshot_id>")
    else:
        restore_cluster(sys.argv[1], sys.argv[2])


if __name__ == "__main__":
    main()
