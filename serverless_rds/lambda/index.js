import { Signer } from "@aws-sdk/rds-signer";
import * as pg from 'pg';
import * as fs from 'node:fs';

const { Client } = pg.default

function runQuery(action, client) {
    if (action === "SELECT") {
        return client.query("SELECT * FROM users")
    } else {
        return client.query("INSERT INTO users (first_name,last_name,age,address) VALUES ('Tomasz', 'Nowak', 70, 'Warszawa')")
    }
}

export const handler = async (event) => {
    const dbEndpoint = process.env.DB_ENDPOINT
    const proxyEndpoint = process.env.PROXY_ENDPOINT
    const dbPort = process.env.DB_PORT
    if (event['db'] === 'PROXY') {
        const user = 'proxy_user'
        const signer = new Signer({
            hostname: proxyEndpoint,
            port: dbPort,
            username: user
        });
        const token = await signer.getAuthToken();
        console.log("Using proxy");
        const client = new Client({
            user,
            host: proxyEndpoint,
            database: 'postgres',
            port: dbPort,
            password: token,
            ssl: {
                ca: fs.readFileSync('proxy_certificate.pem').toString()
            }
        });
        client.connect()
        const result = await runQuery(event['action'], client)
        return result.rows
    } else {
        const user = 'app_user'
        const signer = new Signer({
            hostname: dbEndpoint,
            port: dbPort,
            username: user
        });
        const token = await signer.getAuthToken();
        console.log("Using DB Instance Endpoint");
        const client = new Client({
            user,
            host: dbEndpoint,
            database: 'postgres',
            port: dbPort,
            password: token,
            ssl: {
                ca: fs.readFileSync('db_certificate.pem').toString()
            }
        });
        client.connect()
        const result = await runQuery(event['action'], client)
        return result.rows
    }
}