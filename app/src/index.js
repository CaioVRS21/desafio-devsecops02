const express = require('express')
const { getTest } = require('./test')

const app = express()
const port = process.env.PORT || 3000

app.get('/test', getTest)

app.listen(port, () => {
    console.log(`Listening on http://localhost:${port}`)
})