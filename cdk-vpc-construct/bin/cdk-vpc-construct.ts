#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { CdkVpcConstructStack } from '../lib/cdk-vpc-construct-stack';

const app = new cdk.App();
new CdkVpcConstructStack(app, 'CdkVpcConstructStack');