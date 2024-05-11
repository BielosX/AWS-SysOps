import express from 'express'
import axios from 'axios'
import cookieParser from 'cookie-parser'
import { v4 as UUIDv4 } from 'uuid'
import bodyParser from 'body-parser'
import winston from "winston"

const app = express()
app.use(cookieParser())
app.use(bodyParser.json())
const port = parseInt(process.env.PORT || "8080")

const logger = winston.createLogger({
    transports: [new winston.transports.Console()]
})

const METADATA_URL = 'http://169.254.169.254/latest'
const TOKEN_TTL_HEADER = 'X-aws-ec2-metadata-token-ttl-seconds'
const TOKEN_HEADER = 'X-aws-ec2-metadata-token'
const SESSION_ID_COOKIE_NAME = 'SessionId'

let sessions = {}

const getMetadata = async () => {
    const token = await axios.put(`${METADATA_URL}/api/token`, null, {
        headers: {
            [TOKEN_TTL_HEADER]: '21600'
        }
    })
    const config = {
        headers: {
            [TOKEN_HEADER]: token.data
        }
    }
    const instanceId = axios.get(`${METADATA_URL}/meta-data/instance-id`, config)
    const availabilityZone = axios.get(`${METADATA_URL}/meta-data/placement/availability-zone`, config)
    return {
        'instanceId': (await instanceId).data,
        'availabilityZone': (await availabilityZone).data
    }
}

const metadata = await getMetadata()

app.get('/info', (req, res) => {
    const sessionId = req.cookies[SESSION_ID_COOKIE_NAME]
    let sessionInfo = {}
    if (sessionId) {
        logger.info(`Received SessionId: ${sessionId}`)
        const session = sessions[sessionId]
        if (session) {
            logger.info(`Found session info: ${session}`)
            sessionInfo = session
        } else {
            logger.info(`Session info for SessionId ${sessionId} not found`)
        }
    }
    res.send({...sessionInfo, ...metadata})
})

app.post('/session', (req, res) => {
    const sessionId = UUIDv4()
    sessions[sessionId] = req.body
    logger.info(`Session saved, sessions: ${sessions}`)
    res.cookie(SESSION_ID_COOKIE_NAME, sessionId)
    res.send(metadata)
})

app.get('/health', (req, res) => {
    res.status(200)
    res.send("OK")
})

app.listen(port, () => {
    console.log(`App listening on port ${port}`)
})
