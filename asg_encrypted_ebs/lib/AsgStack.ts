import * as cdk from 'aws-cdk-lib';
import {aws_autoscaling, aws_ec2, aws_iam, Tags} from 'aws-cdk-lib';
import {Construct} from 'constructs';
import {InstanceClass, InstanceSize, InstanceType, IVpc, Peer, Port, SubnetType} from "aws-cdk-lib/aws-ec2";
import * as fs from "fs";
import * as path from "path";
import {AutoScalingGroup} from "aws-cdk-lib/aws-autoscaling";

export interface AsgStackProps {
    vpc: IVpc;
}

export class AsgStack extends cdk.NestedStack {
    public readonly asg: AutoScalingGroup;

    constructor(scope: Construct, id: string, asgProps: AsgStackProps, props?: cdk.StackProps) {
        super(scope, id, props);

        const securityGroup = new aws_ec2.SecurityGroup(this, 'LaunchTemplateSG', { vpc: asgProps.vpc });

        securityGroup.addIngressRule(Peer.anyIpv4(), Port.tcp(80));
        securityGroup.addEgressRule(Peer.anyIpv4(), Port.tcp(443));

        const ec2Role = new aws_iam.Role(this, 'ec2-role', {
            assumedBy: new aws_iam.ServicePrincipal('ec2.amazonaws.com')
        });

        const userData = fs.readFileSync(path.resolve(__dirname, 'init.sh')).toString();

        const launchTemplate = new aws_ec2.LaunchTemplate(this, 'launch-template', {
            machineImage: aws_ec2.MachineImage.lookup({
                name: 'amzn2-ami-hvm-*-x86_64-gp2',
                owners: ['amazon']
            }),
            securityGroup,
            instanceType: InstanceType.of(InstanceClass.T3, InstanceSize.NANO),
            role: ec2Role,
            userData: aws_ec2.UserData.custom(userData)
        });

        this.asg = new aws_autoscaling.AutoScalingGroup(this, 'asg', {
            vpc: asgProps.vpc,
            minCapacity: 2,
            maxCapacity: 4,
            launchTemplate: launchTemplate,
            vpcSubnets: {
                subnetType: SubnetType.PRIVATE_WITH_EGRESS
            },
        });
        Tags.of(this.asg).add('Name', 'demo-asg');
    }
}
