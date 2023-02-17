const WebSocket = require('ws');

const server = new WebSocket.Server({ port: 1324 });
const clients = [];

console.log('WebSocket server is running on port 1324');

server.on('connection', (socket) => {
  console.log('New client connected');

  // add new client to the list
clients.push(socket);

  // send a welcome message to the new client with the current count
  socket.send(`{"from": "Server", "message": "Welcome to anon public chat. There are currently ${clients.length} users online."}`);

  // handle incoming messages from the client
  socket.on('message', (message) => {
    console.log(JSON.parse(message));

    // broadcast the message to all clients
    clients.forEach((client) => {
      client.send(JSON.parse(message));
    });
  });

  // remove the socket from the array when the client disconnects
  socket.on('close', () => {
    console.log('Client disconnected');
    const index = clients.indexOf(socket);
    if (index !== -1) {
      clients.splice(index, 1);
      console.log(`Number of clients: ${clients.length}`);
    }
  });
});