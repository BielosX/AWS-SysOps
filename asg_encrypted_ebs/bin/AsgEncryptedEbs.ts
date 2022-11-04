#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { AsgEncryptedEbsStack } from '../lib/AsgEncryptedEbsStack';

const app = new cdk.App();
new AsgEncryptedEbsStack(app, 'AsgEncryptedEbsStack', {
  env: { account: process.env.CDK_DEFAULT_ACCOUNT, region: process.env.CDK_DEFAULT_REGION }
});