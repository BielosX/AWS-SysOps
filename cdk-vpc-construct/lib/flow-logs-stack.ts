import * as cdk from 'aws-cdk-lib';
import {RemovalPolicy, Stack} from 'aws-cdk-lib';
import {Construct} from "constructs";
import {FlowLogDestination, FlowLogTrafficType, IVpc, Vpc} from "aws-cdk-lib/aws-ec2";
import {BlockPublicAccess, Bucket, ObjectOwnership} from "aws-cdk-lib/aws-s3";

type FlowLogsStackProps = {
    vpcId: string
}

export class FlowLogsStack extends cdk.Stack {
    constructor(scope: Construct, id: string, props: FlowLogsStackProps, stackProps?: cdk.StackProps) {
        super(scope, id, stackProps);
        // Required to be created in Stack scope
        const vpc = Vpc.fromLookup(this, 'SimpleVpc', {
            vpcId: props.vpcId
        });
        const region = Stack.of(this).region;
        const account = Stack.of(this).account;
        const flowLogsBucket = new Bucket(this, 'FlowLogsBucket', {
            bucketName: `simple-vpc-flow-logs-${region}-${account}`,
            blockPublicAccess: BlockPublicAccess.BLOCK_ALL,
            objectOwnership: ObjectOwnership.BUCKET_OWNER_ENFORCED,
            removalPolicy: RemovalPolicy.DESTROY,
            autoDeleteObjects: true
        });
        vpc.addFlowLog('VpcFlowLog', {
            trafficType: FlowLogTrafficType.ALL,
            destination: FlowLogDestination.toS3(flowLogsBucket)
        });
    }
}