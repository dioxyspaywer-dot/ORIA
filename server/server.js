const express = require('express');
const http = require('http');
const WebSocket = require('ws');

const app = express();
app.get('/', (_req, res) => res.json({
  name: 'ORIA signaling prototype',
  status: 'running',
  note: 'No audio/video/screen media is stored or relayed by this prototype.'
}));

const server = http.createServer(app);
const wss = new WebSocket.Server({ server });
const rooms = new Map();

wss.on('connection', (socket) => {
  let room = null;
  socket.on('message', (raw) => {
    let msg;
    try { msg = JSON.parse(raw.toString()); } catch { return; }
    // Démonstration uniquement : authentification et validation indispensables en production.
    if (msg.type === 'join' && typeof msg.room === 'string' && msg.room.length < 100) {
      room = msg.room;
      if (!rooms.has(room)) rooms.set(room, new Set());
      rooms.get(room).add(socket);
      socket.send(JSON.stringify({ type: 'joined', room }));
      return;
    }
    if (!room || !['offer', 'answer', 'ice', 'session-status'].includes(msg.type)) return;
    const peers = rooms.get(room) || new Set();
    for (const peer of peers) {
      if (peer !== socket && peer.readyState === WebSocket.OPEN) {
        peer.send(JSON.stringify({ ...msg, from: 'peer' }));
      }
    }
  });
  socket.on('close', () => {
    if (room && rooms.has(room)) {
      rooms.get(room).delete(socket);
      if (rooms.get(room).size === 0) rooms.delete(room);
    }
  });
});

const port = process.env.PORT || 3000;
server.listen(port, '0.0.0.0', () => console.log(`ORIA signaling server listening on ${port}`));
