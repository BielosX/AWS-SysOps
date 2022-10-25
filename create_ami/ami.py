import boto3
import argparse
import time
import io
import paramiko

from dataclasses import dataclass
from scp import SCPClient


@dataclass
class KeyPair:
    id: str
    fingerprint: str
    material: str
    name: str


class AmiCreator:

    def __init__(self, image_name, root_device_type, instance_type, script_file, no_reboot):
        self.ec2_client = boto3.client('ec2')
        self.ec2 = boto3.resource('ec2')
        self.image_name = image_name
        self.root_device_type = root_device_type
        self.instance_type = instance_type
        self.script_file = script_file
        self.no_reboot = no_reboot

    def create_key_pair(self) -> KeyPair:
        response = self.ec2_client.create_key_pair(
            KeyName='temp-key',
            KeyType='ed25519',
        )
        return KeyPair(
            response['KeyPairId'],
            response['KeyFingerprint'],
            response['KeyMaterial'],
            response['KeyName']
        )

    def remove_key_pair(self, key_pair: KeyPair):
        self.ec2_client.delete_key_pair(
            KeyName=key_pair.name,
            KeyPairId=key_pair.id
        )

    def get_latest_amazon_linux_2(self):
        response = self.ec2_client.describe_images(
            Owners=["amazon"],
            Filters=[
                {
                    'Name': 'architecture',
                    'Values': ['x86_64']
                },
                {
                    'Name': 'root-device-type',
                    'Values': [self.root_device_type]
                },
                {
                    'Name': 'state',
                    'Values': ['available']
                }
            ]
        )
        return list(filter(lambda image: "amzn2-ami-hvm" in image['Name'], response['Images']))[0]

    def create_security_group(self):
        security_group = self.ec2.create_security_group(
            Description='AMI security group',
            GroupName='ami-creator-sg'
        )
        security_group.authorize_ingress(
            CidrIp="0.0.0.0/0",
            FromPort=22,
            ToPort=22,
            IpProtocol='tcp'
        )
        return security_group

    def run_ec2_instance(self, key_name, security_group_id):
        latest_image_id = self.get_latest_amazon_linux_2()['ImageId']
        response = self.ec2.create_instances(
            ImageId=latest_image_id,
            InstanceType=self.instance_type,
            MaxCount=1,
            MinCount=1,
            KeyName=key_name,
            SecurityGroupIds=[security_group_id]
        )
        instance = response[0]
        instance_id = instance.id
        state = instance.state['Name']
        while state != 'running':
            print("Waiting instance {} to become ready, current status: {}".format(instance_id, state))
            time.sleep(20.0)
            instance.reload()
            state = instance.state['Name']
        print("Instance started")
        time.sleep(60.0)
        return instance

    @staticmethod
    def terminate_ec2_instance(instance):
        instance.terminate()
        state = instance.state['Name']
        while state != 'terminated':
            print("Waiting instance {} to terminate".format(instance.id))
            time.sleep(20.0)
            instance.reload()
            state = instance.state['Name']

    def create_image(self, instance):
        image = instance.create_image(
            Name=self.image_name,
            NoReboot=self.no_reboot
        )
        image_state = image.state
        while image_state != 'available':
            print("Image {} not available yet, current state: {}".format(image.image_id, image_state))
            time.sleep(20.0)
            image.reload()
            image_state = image.state
        print("AMI {} created".format(image.image_id))

    def create_image_from_snapshot(self, instance):
        instance.stop()
        state = instance.state['Name']
        while state != 'stopped':
            print("Waiting instance {} to stop. Current state: {}".format(instance.id, state))
            time.sleep(20.0)
            instance.reload()
            state = instance.state['Name']
        root_volume = list(instance.volumes.all())[0]
        snapshot = root_volume.create_snapshot()
        state = snapshot.state
        while state != 'completed':
            print("Waiting for snapshot {} to become ready. Current state: {}".format(snapshot.id, state))
            time.sleep(20.0)
            snapshot.reload()
            state = snapshot.state
        root_device_name = '/dev/sda1'
        image = self.ec2_client.register_image(
            Name=self.image_name,
            RootDeviceName=root_device_name,
            BlockDeviceMappings=[
                {
                    'DeviceName': root_device_name,
                    'Ebs': {
                        'DeleteOnTermination': True,
                        'SnapshotId': snapshot.id
                    }
                }
            ]
        )
        print("AMI {} created".format(image['ImageId']))

    def create(self, from_snapshot=False):
        key_pair = self.create_key_pair()
        security_group = self.create_security_group()
        instance = self.run_ec2_instance(key_pair.name, security_group.group_id)
        instance_key = io.StringIO(key_pair.material)
        ssh_key = paramiko.ed25519key.Ed25519Key.from_private_key(instance_key)
        ssh_client = paramiko.SSHClient()
        ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            ssh_client.connect(instance.public_ip_address,
                               username='ec2-user',
                               pkey=ssh_key,
                               auth_timeout=60.0,
                               banner_timeout=60.0,
                               timeout=60.0)
            remote_path = "/tmp/init-script.sh"
            with SCPClient(ssh_client.get_transport()) as scp:
                scp.put(self.script_file, remote_path=remote_path)
            stdin, stdout, stderr = ssh_client.exec_command("chmod +x {} && sudo {}".format(remote_path, remote_path))
            exit_status = stdout.channel.recv_exit_status()
            print("Exit status: {}".format(exit_status))
            if exit_status == 0:
                if from_snapshot:
                    self.create_image_from_snapshot(instance)
                else:
                    self.create_image(instance)
            else:
                std_out = stdout.readlines()
                std_err = stderr.readlines()
                print("STDOUT:")
                print(std_out)
                print("STDERR:")
                print(std_err)
        finally:
            ssh_client.close()
            self.remove_key_pair(key_pair)
            AmiCreator.terminate_ec2_instance(instance)
            security_group.delete()


def main():
    parser = argparse.ArgumentParser(description="AMI Creator")
    parser.add_argument("--image-name")
    parser.add_argument("--instance-type", default="t3.micro")
    parser.add_argument("--script-file")
    parser.add_argument("--root-device-type", default="ebs", choices=["ebs", "instance-store"])
    parser.add_argument("--reboot", action=argparse.BooleanOptionalAction)
    parser.add_argument("--from-snapshot", action=argparse.BooleanOptionalAction)
    args = parser.parse_args()
    creator = AmiCreator(
        image_name=args.image_name,
        root_device_type=args.root_device_type,
        instance_type=args.instance_type,
        script_file=args.script_file,
        no_reboot=not args.reboot
    )
    creator.create(args.from_snapshot)


if __name__ == "__main__":
    main()
