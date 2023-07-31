import * as cdk from 'aws-cdk-lib';
import {Construct} from "constructs";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import {CfnOutput, Fn, Stack} from "aws-cdk-lib";

type SimpleVpcCfnStackProps = {
    cidrBlock: string,
    subnetBits?: number
};
export class SimpleVpcCfnStack extends cdk.Stack {
    readonly vpcId: string;
    readonly publicSubnetId: string;
    readonly privateSubnetId: string;

    constructor(scope: Construct, id: string, stackProps: SimpleVpcCfnStackProps, props?: cdk.StackProps) {
        super(scope, id, props);
        const vpc = new ec2.CfnVPC(this, 'SimpleVpc', {
            cidrBlock: stackProps.cidrBlock,
            enableDnsHostnames: true,
            enableDnsSupport: true
        });
        this.vpcId = vpc.attrVpcId;
        const subnetBits = stackProps.subnetBits === undefined ? 8 : stackProps.subnetBits;
        const cidr = Fn.cidr(stackProps.cidrBlock, 2, subnetBits.toString());
        const region = Stack.of(this).region;
        const availabilityZones = Fn.getAzs(region);
        const publicSubnet = new ec2.CfnSubnet(this, 'PublicSubnet', {
            cidrBlock: Fn.select(0, cidr),
            mapPublicIpOnLaunch: true,
            vpcId: this.vpcId,
            availabilityZone: Fn.select(0, availabilityZones)
        });
        this.publicSubnetId = publicSubnet.attrSubnetId;
        const privateSubnet = new ec2.CfnSubnet(this, 'PrivateSubnet', {
            cidrBlock: Fn.select(1, cidr),
            mapPublicIpOnLaunch: false,
            vpcId: this.vpcId,
            availabilityZone: Fn.select(0, availabilityZones)
        });
        this.privateSubnetId = privateSubnet.attrSubnetId;
        const internetGateway = new ec2.CfnInternetGateway(this, 'IGW');
        new ec2.CfnVPCGatewayAttachment(this, 'IGWAttachment', {
            internetGatewayId: internetGateway.attrInternetGatewayId,
            vpcId: this.vpcId
        });
        const privateRouteTable = new ec2.CfnRouteTable(this, 'PrivateRouteTable', {
            vpcId: this.vpcId
        });
        const publicRouteTable = new ec2.CfnRouteTable(this, 'PublicRouteTable', {
            vpcId: this.vpcId
        });
        new ec2.CfnSubnetRouteTableAssociation(this, 'PublicRouteTableAssoc', {
            routeTableId: publicRouteTable.attrRouteTableId,
            subnetId: publicSubnet.attrSubnetId
        });
        new ec2.CfnSubnetRouteTableAssociation(this, 'PrivateRouteTableAssoc', {
            routeTableId: privateRouteTable.attrRouteTableId,
            subnetId: privateSubnet.attrSubnetId
        });
        new ec2.CfnRoute(this, 'IGWRoute', {
            routeTableId: publicRouteTable.attrRouteTableId,
            destinationCidrBlock: '0.0.0.0/0',
            gatewayId: internetGateway.attrInternetGatewayId
        });
        const eip = new ec2.CfnEIP(this, 'NatGatewayEIP');
        const natGateway = new ec2.CfnNatGateway(this, 'NatGateway', {
            subnetId: publicSubnet.attrSubnetId,
            allocationId: eip.attrAllocationId
        });
        new ec2.CfnRoute(this, 'NatGatewayRoute', {
            routeTableId: privateRouteTable.attrRouteTableId,
            destinationCidrBlock: '0.0.0.0/0',
            natGatewayId: natGateway.attrNatGatewayId
        });
        new CfnOutput(this, 'VpcIdOutput', {
            exportName: 'simple-vpc-id',
            value: this.vpcId
        })
    }
}