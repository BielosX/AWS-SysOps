import * as cdk from 'aws-cdk-lib';
import {aws_autoscaling, aws_ec2, aws_iam} from 'aws-cdk-lib';
import {Construct} from 'constructs';
import {InstanceClass, InstanceSize, InstanceType, IVpc, Peer, Port} from "aws-cdk-lib/aws-ec2";

export interface AsgStackProps {
    vpc: IVpc;
    albTargetGroupArn: string;
}

export class AsgStack extends cdk.NestedStack {
    public readonly asgName: string;

    constructor(scope: Construct, id: string, asgProps: AsgStackProps, props?: cdk.StackProps) {
        super(scope, id, props);

        const securityGroup = new aws_ec2.SecurityGroup(this, 'LaunchTemplateSG', { vpc: asgProps.vpc });

        securityGroup.addIngressRule(Peer.anyIpv4(), Port.tcp(80));
        securityGroup.addEgressRule(Peer.anyIpv4(), Port.tcp(443));

        const ec2Role = new aws_iam.Role(this, 'ec2-role', {
            assumedBy: new aws_iam.ServicePrincipal('ec2.amazonaws.com')
        });

        const launchTemplate = new aws_ec2.LaunchTemplate(this, 'launch-template', {
            machineImage: aws_ec2.MachineImage.lookup({
                name: 'encrypted-demo-app-image-*'
            }),
            securityGroup,
            instanceType: InstanceType.of(InstanceClass.T3, InstanceSize.NANO),
            role: ec2Role
        });

        const roleArn = `arn:aws:iam::${this.account}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling_EncryptedEbs`;
        const asg = new aws_autoscaling.CfnAutoScalingGroup(this, 'autoscaling-group', {
            minSize: '2',
            maxSize: '4',
            launchTemplate: {
                launchTemplateId: launchTemplate.launchTemplateId,
                version: launchTemplate.versionNumber
            },
            vpcZoneIdentifier: asgProps.vpc.privateSubnets.map(subnet => subnet.subnetId),
            serviceLinkedRoleArn: roleArn,
            targetGroupArns: [asgProps.albTargetGroupArn],
            tags: [
                {
                    propagateAtLaunch: true,
                    key: 'Name',
                    value: 'demo-asg'
                }
            ]
        });
        asg.cfnOptions.updatePolicy = {
            autoScalingRollingUpdate: {
                maxBatchSize: 1,
                minInstancesInService: 1,
                minSuccessfulInstancesPercent: 99
            }
        };
        this.asgName = asg.ref;
    }
}
