import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import {VpcConstruct} from "./vpc-construct";

export class CdkVpcConstructStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);
    new VpcConstruct(this, 'Vpc', {
      singleNATGateway: true
    });
  }
}
