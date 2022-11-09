import {S3} from "aws-sdk";

type LambdaEvent = {
    endpoint: string,
    path: string,
    action: string,
    payload?: string
}

const s3 = new S3();

async function getObject(endpoint: string, path: string): Promise<string> {
    const response = await s3.getObject({
        Bucket: endpoint,
        Key: path
    }).promise();
    return response.Body?.toString() ?? "";
}

async function putObject(endpoint: string, path: string, payload: string) {
    await s3.putObject({
        Bucket: endpoint,
        Key: path,
        Body: payload
    }).promise();
}

export const handler = async (event: LambdaEvent) => {
    const bucket = process.env.BUCKET;
    const accessPointArn = process.env.AP_ARN;
    let endpoint = "";
    switch (event.endpoint) {
        case "BUCKET":
            endpoint = bucket ?? "";
            break;
        case "AP":
            endpoint = accessPointArn ?? "";
            break;
        default:
            throw new Error("endpoint is BUCKET or AP");
    }
    switch (event.action) {
        case "GET":
            return getObject(endpoint, event.path);
        case "PUT":
            return putObject(endpoint, event.path, event.payload ?? "");
        default:
            throw new Error("action is GET or PUT");
    }
}