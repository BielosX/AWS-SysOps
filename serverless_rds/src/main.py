import boto3
import os
import pg8000.native
import ssl

client = boto3.client('rds')


def handle(event, context):
    db_endpoint = os.environ['DB_ENDPOINT']
    region = os.environ['REGION']
    token = client.generate_db_auth_token(DBHostname=db_endpoint, Port=5432, DBUsername='app_user', Region=region)
    ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    ssl_context.load_verify_locations('certificate.pem')
    conn = pg8000.native.Connection("app_user", host=db_endpoint, port=5432, password=token, ssl_context=ssl_context)
    if event['action'] == "SELECT":
        return conn.run("SELECT * FROM users")
    else:
        conn.run("INSERT INTO users (first_name,last_name,age,address) VALUES ('Tomasz', 'Nowak', 70, 'Warszawa')")
        return "OK"
