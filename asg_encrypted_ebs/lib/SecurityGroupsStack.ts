import * as cdk from 'aws-cdk-lib';
import {Construct} from "constructs";
import {aws_ec2} from "aws-cdk-lib";
import {IVpc, Peer, Port, SecurityGroup} from "aws-cdk-lib/aws-ec2";

export interface SecurityGroupsStackProps {
    vpc: IVpc;
}

export class SecurityGroupsStack extends cdk.NestedStack {
    public readonly instanceSecurityGroup: SecurityGroup;
    public readonly albSecurityGroup: SecurityGroup;

    constructor(scope: Construct, id: string, sgProps: SecurityGroupsStackProps, props?: cdk.StackProps) {
        super(scope, id, props);

        this.instanceSecurityGroup = new aws_ec2.SecurityGroup(this, 'instance-sg', {
            vpc: sgProps.vpc
        });

        this.instanceSecurityGroup.addIngressRule(Peer.anyIpv4(), Port.tcp(80));
        this.instanceSecurityGroup.addEgressRule(Peer.anyIpv4(), Port.tcp(443));

        this.albSecurityGroup = new aws_ec2.SecurityGroup(this, 'alb-sg', {
            vpc: sgProps.vpc
        });

        this.albSecurityGroup.addIngressRule(Peer.anyIpv4(), Port.tcp(80));
        this.albSecurityGroup.addEgressRule(this.instanceSecurityGroup, Port.tcp(80));
    }
}
