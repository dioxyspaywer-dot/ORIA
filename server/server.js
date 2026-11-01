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
  console.log(`🔌 [SERVER] Nouvelle connexion: ${socket.id}`);

  // ✅ ENFANT S'ENREGISTRE ET REJOINT SA SALLE
  socket.on('register_child', async (data) => {
    const room = `device:${data.deviceId}`;
    socket.join(room);
    console.log(`👶 [SERVER] CHILD_REGISTERED: ${data.deviceId} → salle ${room}`);

    await Device.findOneAndUpdate(
      { deviceId: data.deviceId },
      { deviceName: data.deviceName || 'Inconnu', status: 'online', lastSeen: new Date() },
      { upsert: true, new: true }
    );
    io.emit('device_list_updated');
  });

  // ✅ PARENT S'ENREGISTRE ET REJOINT SA SALLE
  socket.on('register_parent', (parentId) => {
    const room = `device:${parentId}`;
    socket.join(room);
    console.log(`👨‍👩‍👧 [SERVER] PARENT_REGISTERED: ${parentId} → salle ${room}`);
  });

  socket.on('get_devices', async () => {
    const devices = await Device.find({}).sort({ lastSeen: -1 });
    socket.emit('device_list', devices);
  });

  socket.on('rename_device', async (data) => {
    await Device.findOneAndUpdate({ _id: data.deviceId }, { customName: data.newName });
    io.emit('device_list_updated');
  });

  // ✅ COMMANDES ROUTÉES VERS LA BONNE SALLE + LOGS
  socket.on('command', (data) => {
    const targetRoom = `device:${data.targetId}`;
    console.log(`📡 [SERVER] COMMAND_ROUTED: ${data.action} → ${targetRoom}`);
    io.to(targetRoom).emit('execute_command', { action: data.action, requestId: data.requestId || Date.now().toString() });
  });

  // ✅ SIGNALISATION WEBRTC - FORMAT UNIFORMISÉ
  // L'enfant/parent envoie: { target, type, data }
  // Le serveur transmet TEL QUEL (sans unwrap)
  socket.on('signal', (msg) => {
    const targetRoom = `device:${msg.target}`;
    console.log(`🔄 [SERVER] SIGNAL_RELAYED: ${msg.type} → ${targetRoom}`);
    io.to(targetRoom).emit('signal', msg);
  });

  // ✅ STATUT OFFLINE À LA DÉCONNEXION
  socket.on('disconnect', async () => {
    console.log(`🔌 [SERVER] DISCONNECT: ${socket.id}`);
    // Optionnel: mettre hors ligne après délai pour éviter les faux négatifs
  });
});

setInterval(() => console.log('💓 [SERVER] Keep-alive'), 240000);

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`🚀 [SERVER] ORIA démarré sur port ${PORT}`));