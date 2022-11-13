import * as cdk from 'aws-cdk-lib';
import {Construct} from 'constructs';
import {VpcStack} from "./VpcStack";
import {AsgStack} from "./AsgStack";
import {LoadBalancer} from "./LoadBalancer";
import {SecurityGroupsStack} from "./SecurityGroupsStack";

export class AsgEncryptedEbsStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const vpc = new VpcStack(this, 'simple-vpc-stack', {
      cidrBlock: '10.0.0.0/16',
      vpcName: 'simple-vpc'
    });

    const sg = new SecurityGroupsStack(this, 'security-groups-stack', {
      vpc: vpc.vpc
    });

    const alb = new LoadBalancer(this, 'load-balancer-stack', {
      vpc: vpc.vpc,
      albSg: sg.albSecurityGroup
    });

    const asg = new AsgStack(this, 'asg-stack', {
      vpc: vpc.vpc,
      albTargetGroupArn: alb.targetGroupArn,
      instanceSg: sg.instanceSecurityGroup
    });

  }
}
