import * as cdk from 'aws-cdk-lib';
import {Construct} from 'constructs';
import {VpcConstruct} from "./vpc-construct";
import {GatewayVpcEndpointAwsService, InterfaceVpcEndpointAwsService, SubnetType} from "aws-cdk-lib/aws-ec2";

export class VpcConstructStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);
    const vpc = new VpcConstruct(this, 'Vpc', {
      singleNATGateway: true
    });
    vpc.addGatewayEndpoint('DynamoDbEndpoint', {
      service: GatewayVpcEndpointAwsService.DYNAMODB
    });
    vpc.addInterfaceEndpoint('EKSEndpoint', {
      service: InterfaceVpcEndpointAwsService.EKS,
      open: true,
      subnets: vpc.selectSubnets({
        subnetType: SubnetType.PRIVATE_WITH_EGRESS
      })
    })
  }
}
