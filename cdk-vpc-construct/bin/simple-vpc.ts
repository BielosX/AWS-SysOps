#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import {SimpleVpcCfnStack} from "../lib/simple-vpc-cfn-stack";

const app = new cdk.App();
new SimpleVpcCfnStack(app, 'SimpleVpc', {
    cidrBlock: '10.0.0.0/16'
});
app.synth();