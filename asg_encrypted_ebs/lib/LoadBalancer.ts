import * as cdk from 'aws-cdk-lib';
import {aws_elasticloadbalancingv2, Duration} from 'aws-cdk-lib';
import {Construct} from "constructs";
import {AutoScalingGroup} from "aws-cdk-lib/aws-autoscaling";
import {IVpc} from "aws-cdk-lib/aws-ec2";
import {ApplicationProtocol, TargetType} from "aws-cdk-lib/aws-elasticloadbalancingv2";

export interface LoadBalancerProps {
    asg: AutoScalingGroup;
    vpc: IVpc;
}

export class LoadBalancer extends cdk.NestedStack {
    constructor(scope: Construct,
                id: string,
                lbProps: LoadBalancerProps,
                props?: cdk.StackProps) {
        super(scope, id, props);

        const alb = new aws_elasticloadbalancingv2.ApplicationLoadBalancer(this, 'alb', {
            vpc: lbProps.vpc,
            internetFacing: true
        });

        const listener = alb.addListener('listener', {
            port: 80,
            protocol: ApplicationProtocol.HTTP,
            open: true
        });

        const targetGroup = new aws_elasticloadbalancingv2.ApplicationTargetGroup(this, 'target-group', {
            targetType: TargetType.INSTANCE,
            port: 80,
            protocol: ApplicationProtocol.HTTP,
            vpc: lbProps.vpc,
            targets: [lbProps.asg],
            healthCheck: {
                path: '/index.html',
                healthyThresholdCount: 2,
                unhealthyThresholdCount: 2,
                timeout: Duration.seconds(20),
                interval: Duration.seconds(30),
                healthyHttpCodes: '200'
            }
        });

        listener.addTargetGroups('alb-target-group', {
            targetGroups: [targetGroup]
        });
    }
}