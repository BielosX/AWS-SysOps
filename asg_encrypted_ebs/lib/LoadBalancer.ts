import * as cdk from 'aws-cdk-lib';
import {aws_elasticloadbalancingv2, Duration} from 'aws-cdk-lib';
import {Construct} from "constructs";
import {IVpc} from "aws-cdk-lib/aws-ec2";
import {ApplicationProtocol, TargetType} from "aws-cdk-lib/aws-elasticloadbalancingv2";

export interface LoadBalancerProps {
    vpc: IVpc;
}

export class LoadBalancer extends cdk.NestedStack {
    public readonly targetGroupArn: string;
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
            healthCheck: {
                path: '/index.html',
                healthyThresholdCount: 2,
                unhealthyThresholdCount: 2,
                timeout: Duration.seconds(20),
                interval: Duration.seconds(30),
                healthyHttpCodes: '200'
            }
        });

        this.targetGroupArn = targetGroup.targetGroupArn;

        listener.addTargetGroups('alb-target-group', {
            targetGroups: [targetGroup]
        });
    }
}