const http = require('http');
const lodash = require('lodash');

const PORT = 3000;

const server = http.createServer((req, res) => {
    if (req.url === '/') {
        const message = lodash.capitalize('supply chain security lab');

        res.writeHead(200, {
            'Content-Type': 'application/json'
        });

        res.end(JSON.stringify({
            application: message,
            version: 'tampered',
            status: 'running'
        }));

        return;
    }

    res.writeHead(404);
    res.end('Not Found');
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`API running on port ${PORT}`);
});