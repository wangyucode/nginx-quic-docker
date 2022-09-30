const http = require('http');

const port = 8082;

const server = http.createServer((req, res) => {
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/plain');
  res.end('你好世界\n');
})

server.listen(port, () => {
  console.log(`服务器运行在 ${port}`);
});