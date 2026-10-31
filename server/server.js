const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const mongoose = require('mongoose');
const cors = require('cors');

const app = express();
app.use(cors());
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost/oria')
  .then(() => console.log('✅ MongoDB connecté'))
  .catch(err => console.error('❌ Erreur MongoDB:', err));

const DeviceSchema = new mongoose.Schema({
  deviceId: { type: String, unique: true },
  deviceName: String,
  customName: String,
  status: { type: String, default: 'offline' },
  lastSeen: { type: Date, default: Date.now }
});
const Device = mongoose.model('Device', DeviceSchema);

io.on('connection', (socket) => {
  console.log('🔌 Connecté:', socket.id);

  socket.on('register_child', async (data) => {
    await Device.findOneAndUpdate(
      { deviceId: data.deviceId },
      { deviceName: data.deviceName || 'Inconnu', status: 'online', lastSeen: new Date() },
      { upsert: true, new: true }
    );
    io.emit('device_list_updated');
  });

  socket.on('get_devices', async () => {
    const devices = await Device.find({}).sort({ lastSeen: -1 });
    socket.emit('device_list', devices);
  });

  socket.on('rename_device', async (data) => {
    await Device.findOneAndUpdate({ _id: data.deviceId }, { customName: data.newName });
    io.emit('device_list_updated');
  });

  socket.on('command', (data) => {
    console.log(`📡 ${data.action} -> ${data.targetId}`);
    io.to(data.targetId).emit('execute_command', data.action);
  });

  socket.on('signal', (data) => io.to(data.target).emit('signal', data.payload));

  socket.on('disconnect', () => console.log('🔌 Déconnexion:', socket.id));
});

// ✅ Ping pour empêcher Render de dormir
setInterval(() => {
  console.log('💓 Keep-alive ping');
}, 240000);

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`🚀 Serveur ORIA sur port ${PORT}`));