import boto3
import os
import pg8000.native
import ssl
import json

client = boto3.client('rds')
secrets_client = boto3.client('secretsmanager')


def handle(event, context):
    db_endpoint = os.environ['DB_ENDPOINT']
    proxy_endpoint = os.environ['PROXY_ENDPOINT']
    region = os.environ['REGION']
    db_port = os.environ['DB_PORT']
    ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    if event['db'] == "PROXY":
        ssl_context.load_verify_locations('proxy_certificate.pem')
        user = "proxy_user"
        token = client.generate_db_auth_token(DBHostname=proxy_endpoint,
                                              Port=db_port,
                                              DBUsername=user,
                                              Region=region)
        conn = pg8000.native.Connection(user,
                                        host=proxy_endpoint,
                                        port=db_port,
                                        database="postgres",
                                        password=token.encode('ascii'),
                                        ssl_context=ssl_context)
    else:
        ssl_context.load_verify_locations('db_certificate.pem')
        user = "app_user"
        token = client.generate_db_auth_token(DBHostname=db_endpoint,
                                              Port=db_port,
                                              DBUsername=user,
                                              Region=region)
        conn = pg8000.native.Connection(user,
                                        host=db_endpoint,
                                        port=db_port,
                                        database="postgres",
                                        password=token,
                                        ssl_context=ssl_context)
    if event['action'] == "SELECT":
        result = conn.run("SELECT * FROM users")
        return json.dumps(result, indent=4, sort_keys=True, default=str)
    else:
        conn.run("INSERT INTO users (first_name,last_name,age,address) VALUES ('Tomasz', 'Nowak', 70, 'Warszawa')")
        return "OK"
