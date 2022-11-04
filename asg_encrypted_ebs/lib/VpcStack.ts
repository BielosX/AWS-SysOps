import * as cdk from 'aws-cdk-lib';
import {Construct} from 'constructs';
import {aws_ec2} from "aws-cdk-lib";
import {IVpc, Vpc} from "aws-cdk-lib/aws-ec2";

export interface VpcProps {
    vpcName: string;
    cidrBlock: string;
}

export class VpcStack extends cdk.NestedStack {
    public readonly vpc: IVpc;

    constructor(scope: Construct, id: string, vpcProps: VpcProps, props?: cdk.StackProps) {
        super(scope, id, props);

        const cidrCount = 4;
        const generatedCidr = cdk.Fn.cidr(vpcProps.cidrBlock, cidrCount, '8');
        const subnetsCidr: string[] = [];
        [...Array(cidrCount).keys()].forEach(i => {
            subnetsCidr.push(cdk.Fn.select(i, generatedCidr))
        });

        const allAvailableZones = cdk.Fn.getAzs();
        const availabilityZones: string[] = [];
        availabilityZones.push(cdk.Fn.select(0, allAvailableZones),
            cdk.Fn.select(1, allAvailableZones));

        const vpc = new aws_ec2.CfnVPC(this, 'simple-vpc', {
            cidrBlock: vpcProps.cidrBlock,
            enableDnsHostnames: true,
            enableDnsSupport: true,
            tags: [
                {
                    key: 'Name',
                    value: vpcProps.vpcName
                }
            ]
        });

        const vpcId = vpc.attrVpcId;

        const internetGateway = new aws_ec2.CfnInternetGateway(this, 'internet-gateway', {
            tags: [
                {
                    key: 'Name',
                    value: `${vpcProps.vpcName}-internet-gateway`
                }
            ]
        });

        new aws_ec2.CfnVPCGatewayAttachment(this, 'igw-attachment', {
            internetGatewayId: internetGateway.attrInternetGatewayId,
            vpcId
        });

        const publicRouteTable = new aws_ec2.CfnRouteTable(this, 'public-route-table', {
            vpcId: vpcId,
            tags: [
                {
                    key: 'Name',
                    value: `${vpcProps.vpcName}-public-route-table`
                }
            ]
        });

        new aws_ec2.CfnRoute(this, 'igw-route', {
            destinationCidrBlock: '0.0.0.0/0',
            gatewayId: internetGateway.attrInternetGatewayId,
            routeTableId: publicRouteTable.attrRouteTableId
        });

        const firstPublicSubnet = new aws_ec2.CfnSubnet(this, 'first-public-subnet', {
            cidrBlock: subnetsCidr[0],
            availabilityZone: availabilityZones[0],
            vpcId: vpcId,
            mapPublicIpOnLaunch: true,
            tags: [
                {
                    key: 'Name',
                    value: `${vpcProps.vpcName}-first-public-subnet`
                }
            ]
        });

        const secondPublicSubnet = new aws_ec2.CfnSubnet(this, 'second-public-subnet', {
            cidrBlock: subnetsCidr[1],
            availabilityZone: availabilityZones[1],
            vpcId: vpcId,
            mapPublicIpOnLaunch: true,
            tags: [
                {
                    key: 'Name',
                    value: `${vpcProps.vpcName}-second-public-subnet`
                }
            ]
        });

        [firstPublicSubnet, secondPublicSubnet].forEach((subnet, index) => {
            new aws_ec2.CfnSubnetRouteTableAssociation(this, `public-route-table-assoc-${index}`, {
                routeTableId: publicRouteTable.attrRouteTableId,
                subnetId: subnet.attrSubnetId
            });
        });

        const eip = new aws_ec2.CfnEIP(this, 'nat-gateway-eip', {
            domain: 'vpc',
            tags: [
                {
                    key: 'Name',
                    value: `${vpcProps.vpcName}-nat-gateway-eip`
                }
            ]
        });

        const natGateway = new aws_ec2.CfnNatGateway(this, 'nat-gateway', {
            subnetId: firstPublicSubnet.attrSubnetId,
            allocationId: eip.attrAllocationId,
            tags: [
                {
                    key: 'Name',
                    value: `${vpcProps.vpcName}-nat-gateway`
                }
            ]
        });


        const firstPrivateSubnet = new aws_ec2.CfnSubnet(this, 'first-private-subnet', {
            cidrBlock: subnetsCidr[2],
            availabilityZone: availabilityZones[0],
            vpcId: vpcId,
            mapPublicIpOnLaunch: false,
            tags: [
                {
                    key: 'Name',
                    value: `${vpcProps.vpcName}-first-private-subnet`
                }
            ]
        });

        const secondPrivateSubnet = new aws_ec2.CfnSubnet(this, 'second-private-subnet', {
            cidrBlock: subnetsCidr[3],
            availabilityZone: availabilityZones[1],
            vpcId: vpcId,
            mapPublicIpOnLaunch: false,
            tags: [
                {
                    key: 'Name',
                    value: `${vpcProps.vpcName}-second-private-subnet`
                }
            ]
        });

        const privateRouteTable = new aws_ec2.CfnRouteTable(this, 'private-route-table', {
            vpcId: vpcId,
            tags: [
                {
                    key: 'Name',
                    value: `${vpcProps.vpcName}-private-route-table`
                }
            ]
        });

        new aws_ec2.CfnRoute(this, 'nat-gateway-route', {
            destinationCidrBlock: '0.0.0.0/0',
            natGatewayId: natGateway.attrNatGatewayId,
            routeTableId: privateRouteTable.attrRouteTableId
        });

        [firstPrivateSubnet, secondPrivateSubnet].forEach((subnet, index) => {
            new aws_ec2.CfnSubnetRouteTableAssociation(this, `private-route-table-assoc-${index}`, {
                routeTableId: privateRouteTable.attrRouteTableId,
                subnetId: subnet.attrSubnetId
            });
        });

        this.vpc = Vpc.fromVpcAttributes(this, 'vpc', {
            vpcId: vpc.ref,
            availabilityZones,
            privateSubnetIds: [firstPrivateSubnet.ref, secondPrivateSubnet.ref],
            publicSubnetIds: [firstPublicSubnet.ref, secondPublicSubnet.ref],
            publicSubnetRouteTableIds: [publicRouteTable.ref, publicRouteTable.ref],
            privateSubnetRouteTableIds: [privateRouteTable.ref, privateRouteTable.ref]
        });
    }
}
