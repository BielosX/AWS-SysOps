import express from 'express'
import { v4 as UUIDv4 } from 'uuid'
import {logger} from "./logger"
import {metadata} from "./metadata"
import {sessionSchema, validateSchema} from "./schemas";

export const router = express.Router()

const SESSION_ID_COOKIE_NAME = 'SessionId'

let sessions = {}

router.get('/info', (req, res) => {
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

router.post('/session', validateSchema(sessionSchema), (req, res) => {
    const sessionId = UUIDv4()
    sessions[sessionId] = req.body
    logger.info(`Session saved, sessions: ${sessions}`)
    res.cookie(SESSION_ID_COOKIE_NAME, sessionId)
    res.send(metadata)
})

router.get('/health', (req, res) => {
    res.status(200)
    res.send("OK")
})