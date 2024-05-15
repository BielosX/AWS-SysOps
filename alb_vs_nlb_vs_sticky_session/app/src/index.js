import express from 'express'
import cookieParser from 'cookie-parser'
import bodyParser from 'body-parser'
import {
    router
} from "./routes"

const app = express()
app.use(cookieParser())
app.use(bodyParser.json())
app.use('/', router)
const port = parseInt(process.env.PORT || "8080")

app.listen(port, () => {
    console.log(`App listening on port ${port}`)
})