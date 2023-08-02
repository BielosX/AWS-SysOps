import * as cdk from 'aws-cdk-lib';
import {Duration, RemovalPolicy} from 'aws-cdk-lib';
import {Construct} from 'constructs';
import {Code, Function, Runtime} from 'aws-cdk-lib/aws-lambda';
import {FilterPattern, LogGroup} from "aws-cdk-lib/aws-logs";
import {LambdaDestination} from "aws-cdk-lib/aws-logs-destinations";
import {AttributeType, BillingMode, ProjectionType, Table} from "aws-cdk-lib/aws-dynamodb";
import {Effect, PolicyStatement} from "aws-cdk-lib/aws-iam";

type LambdaStackProps = {
  codePath: string
};

export class LambdaStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: LambdaStackProps, stackProps?: cdk.StackProps) {
    super(scope, id, stackProps);

    const dynamoTable = new Table(this, 'LogsTable', {
      removalPolicy: RemovalPolicy.DESTROY,
      tableName: 'logs-table',
      partitionKey: {
        name: 'id',
        type: AttributeType.STRING
      },
      billingMode: BillingMode.PAY_PER_REQUEST
    });
    dynamoTable.addGlobalSecondaryIndex({
      indexName: 'timestamp-index',
      projectionType: ProjectionType.ALL,
      partitionKey: {
        name: 'timestamp',
        type: AttributeType.NUMBER
      }
    });

    const logGroup = new LogGroup(this, 'DemoLogGroup', {
      logGroupName: 'demo-log-group',
      removalPolicy: RemovalPolicy.DESTROY
    });

    const springFunction = new Function(this, 'SpringBootLambda', {
      functionName: 'cloud-watch-logs-processing-lambda',
      runtime: Runtime.JAVA_17,
      code: Code.fromAsset(props.codePath),
      handler: "com.example.LogsHandler::handleRequest",
      timeout: Duration.minutes(5),
      memorySize: 1024,
      environment: {
        LOGS_TABLE: dynamoTable.tableName
      }
    });

    const policyStatement = new PolicyStatement();
    policyStatement.addActions("dynamodb:PutItem");
    policyStatement.addResources("*");
    policyStatement.effect = Effect.ALLOW;
    springFunction.addToRolePolicy(policyStatement);

    logGroup.addSubscriptionFilter('SubscriptionFilter', {
      destination: new LambdaDestination(springFunction),
      filterPattern: FilterPattern.allEvents()
    })
  }
}
