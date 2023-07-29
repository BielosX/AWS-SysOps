import {Construct, DependencyGroup, IDependable} from 'constructs';
import * as ec2 from "aws-cdk-lib/aws-ec2";
import {CfnResource, Fn, RemovalPolicy, ResourceEnvironment, Stack} from "aws-cdk-lib";

export type VpcConstructProps = {
    availabilityZones?: string[],
    cidrBlock?: string,
    subnetBits?: number,
    singleNATGateway?: boolean
};

export class VpcConstruct extends Construct implements ec2.IVpc {
    readonly availabilityZones: string[];
    readonly env: ResourceEnvironment;
    readonly internetConnectivityEstablished: IDependable;
    readonly isolatedSubnets: ec2.ISubnet[];
    readonly privateSubnets: ec2.ISubnet[];
    readonly publicSubnets: ec2.ISubnet[];
    readonly stack: Stack;
    readonly vpcArn: string;
    readonly vpcCidrBlock: string;
    readonly vpcId: string;

    readonly cfnResources: CfnResource[];

    constructor(scope: Construct, id: string, props: VpcConstructProps) {
        super(scope, id);
        const cidrBlock = props.cidrBlock === undefined ? "10.0.0.0/16" : props.cidrBlock;
        const vpc = new ec2.CfnVPC(this, 'Vpc', {
            cidrBlock,
            enableDnsHostnames: true,
            enableDnsSupport: true
        });
        this.env = {
            account: vpc.stack.account,
            region: vpc.stack.region
        };
        this.cfnResources = [];
        this.isolatedSubnets = [];
        this.privateSubnets = [];
        this.publicSubnets = [];
        this.stack = Stack.of(this);
        const defaultAZsTokens = Fn.getAzs(this.stack.region);
        const defaultAZs: string[] = Array.from(Array(2).keys())
            .map(idx => Fn.select(idx, defaultAZsTokens));
        this.availabilityZones = props.availabilityZones === undefined ? defaultAZs : props.availabilityZones;
        const partition = this.stack.partition;
        const region = this.stack.region;
        const account = this.stack.account;
        this.vpcId = vpc.attrVpcId;
        this.vpcArn = `arn:${partition}:ec2:${region}:${account}:vpc/${this.vpcId}`;
        this.vpcCidrBlock = vpc.attrCidrBlock;
        this.cfnResources.push(vpc);
        const dependencyGroup = new DependencyGroup();

        const subnetBits = props.subnetBits === undefined ? 8 : props.subnetBits;
        const numberOfCidrBlocks = this.availabilityZones.length * 2;
        const cidrTokens = Fn.cidr(cidrBlock, numberOfCidrBlocks, subnetBits.toString());
        const cidrBlocks: string[] = Array.from(Array(numberOfCidrBlocks).keys())
            .map(idx => Fn.select(idx, cidrTokens));
        const internetGateway = new ec2.CfnInternetGateway(this, 'InternetGateway');
        const igwAttachment = new ec2.CfnVPCGatewayAttachment(this, 'IGWAttachment', {
            internetGatewayId: internetGateway.attrInternetGatewayId,
            vpcId: this.vpcId
        });

        const publicRouteTable = new ec2.CfnRouteTable(this, 'PublicRouteTable', {
            vpcId: this.vpcId
        });
        const toIgwRoute = new ec2.CfnRoute(this, `ToIGWRoute`, {
            routeTableId: publicRouteTable.attrRouteTableId,
            gatewayId: internetGateway.attrInternetGatewayId,
            destinationCidrBlock: '0.0.0.0/0'
        });
        dependencyGroup.add(toIgwRoute);
        const privateRouteTable = new ec2.CfnRouteTable(this, 'PrivateRouteTable', {
            vpcId: this.vpcId
        });

        this.cfnResources.push(internetGateway, igwAttachment, publicRouteTable, privateRouteTable, toIgwRoute);

        for(let idx = 0; idx < cidrBlocks.length / 2; idx++) {
            const publicSubnet = new ec2.CfnSubnet(this, `PublicSubnet${idx}`, {
                vpcId: this.vpcId,
                mapPublicIpOnLaunch: true,
                cidrBlock: cidrBlocks[idx],
                availabilityZone: this.availabilityZones[idx % this.availabilityZones.length]
            });
            const publicSubnetRouteTableAssoc = new ec2.CfnSubnetRouteTableAssociation(this,
                `PublicSubnet${idx}RouteTableAssoc`,{
                    routeTableId: publicRouteTable.attrRouteTableId,
                    subnetId: publicSubnet.attrSubnetId
                });
            const publicSubnetResource = ec2.Subnet.fromSubnetAttributes(this,
                `PublicSubnetResource${idx}`, {
                    subnetId: publicSubnet.attrSubnetId,
                    routeTableId: publicRouteTable.attrRouteTableId,
                    availabilityZone: publicSubnet.availabilityZone,
                    ipv4CidrBlock: publicSubnet.cidrBlock
                });
            this.publicSubnets.push(publicSubnetResource);
            if (props.singleNATGateway) {
                if (idx === 0) {
                    this.createNatGateway(idx.toString(),
                        publicSubnet.attrSubnetId,
                        privateRouteTable.attrRouteTableId,
                        dependencyGroup);
                }
            } else {
                this.createNatGateway(idx.toString(),
                    publicSubnet.attrSubnetId,
                    privateRouteTable.attrRouteTableId,
                    dependencyGroup);
            }
            this.cfnResources.push(publicSubnet, publicSubnetRouteTableAssoc);
        }

        for(let idx = cidrBlocks.length / 2; idx < cidrBlocks.length; idx++) {
            const privateSubnet = new ec2.CfnSubnet(this, `PrivateSubnet${idx}`, {
                vpcId: this.vpcId,
                mapPublicIpOnLaunch: false,
                cidrBlock: cidrBlocks[idx],
                availabilityZone: this.availabilityZones[idx % this.availabilityZones.length]
            });
            const privateSubnetRouteTableAssoc = new ec2.CfnSubnetRouteTableAssociation(this,
                `PrivateSubnet${idx}RouteTableAssoc`, {
                    routeTableId: privateRouteTable.attrRouteTableId,
                    subnetId: privateSubnet.attrSubnetId
                });
            const privateSubnetResource = ec2.Subnet.fromSubnetAttributes(this,
                `PrivateSubnetResource${idx}`,
                {
                    subnetId: privateSubnet.attrSubnetId,
                    routeTableId: publicRouteTable.attrRouteTableId,
                    availabilityZone: privateSubnet.availabilityZone,
                    ipv4CidrBlock: privateSubnet.cidrBlock
                });
            this.privateSubnets.push(privateSubnetResource)
            this.cfnResources.push(privateSubnet,
                privateSubnetRouteTableAssoc);
        }
        this.internetConnectivityEstablished = dependencyGroup;
    }

    private createNatGateway(suffix: string, subnetId: string, routeTableId: string, group: DependencyGroup): void {
        const eip = new ec2.CfnEIP(this, `ElasticIP${suffix}`);
        const natGateway = new ec2.CfnNatGateway(this, `NatGateway${suffix}`, {
            subnetId: subnetId,
            allocationId: eip.attrAllocationId
        });
        const toNatGatewayRoute = new ec2.CfnRoute(this, `ToNatGatewayRoute${suffix}`, {
            routeTableId,
            natGatewayId: natGateway.attrNatGatewayId,
            destinationCidrBlock: '0.0.0.0/0'
        });
        this.cfnResources.push(eip, natGateway, toNatGatewayRoute);
        group.add(natGateway, toNatGatewayRoute);
    }

    addClientVpnEndpoint(id: string, options: ec2.ClientVpnEndpointOptions): ec2.ClientVpnEndpoint {
        throw new Error();
    }

    addFlowLog(id: string, options?: ec2.FlowLogOptions): ec2.FlowLog {
        throw new Error();
    }

    addGatewayEndpoint(id: string, options: ec2.GatewayVpcEndpointOptions): ec2.GatewayVpcEndpoint {
        throw new Error();
    }

    addInterfaceEndpoint(id: string, options: ec2.InterfaceVpcEndpointOptions): ec2.InterfaceVpcEndpoint {
        throw new Error();
    }

    addVpnConnection(id: string, options: ec2.VpnConnectionOptions): ec2.VpnConnection {
        throw new Error();
    }

    applyRemovalPolicy(policy: RemovalPolicy): void {
        this.cfnResources.forEach(resource => resource.applyRemovalPolicy(policy));
    }

    enableVpnGateway(options: ec2.EnableVpnGatewayOptions): void {
    }

    selectSubnets(selection?: ec2.SubnetSelection): ec2.SelectedSubnets {
        throw new Error();
    }
}