#!/usr/bin/env node
import 'source-map-support/register';
import {FlowLogsStack} from "../lib/flow-logs-stack";
import {App} from "aws-cdk-lib";

const app = new App();
const vpcId = app.node.tryGetContext('vpcId');
new FlowLogsStack(app, 'FlowLogsStack', {
    vpcId
}, {
    env: {
        // Required for Vpc.fromLookup()
        account: process.env.CDK_DEFAULT_ACCOUNT,
        region: process.env.CDK_DEFAULT_REGION
    }
});
app.synth();