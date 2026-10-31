const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const mongoose = require('mongoose');
const cors = require('cors');

const app = express();
app.use(cors());
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

// Connexion MongoDB (Utilise la variable d'environnement Render)
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost/oria')
  .then(() => console.log('✅ MongoDB connecté'))
  .catch(err => console.error('❌ Erreur MongoDB:', err));

const DeviceSchema = new mongoose.Schema({
  deviceId: { type: String, unique: true },
  deviceName: String,
  status: { type: String, default: 'offline' },
  lastSeen: { type: Date, default: Date.now }
});
const Device = mongoose.model('Device', DeviceSchema);

io.on('connection', (socket) => {
  console.log('🔌 Nouvelle connexion:', socket.id);

  // L'enfant s'enregistre automatiquement
  socket.on('register_child', async (data) => {
    try {
      await Device.findOneAndUpdate(
        { deviceId: data.deviceId },
        {
          deviceName: data.deviceName || 'Appareil Inconnu',
          status: 'online',
          lastSeen: new Date()
        },
        { upsert: true, new: true }
      );
      console.log(`👶 Enfant enregistré: ${data.deviceId}`);
      io.emit('device_list_updated');
    } catch (e) {
      console.error('Erreur enregistrement:', e);
    }
  });

  // Le parent demande la liste des enfants
  socket.on('get_devices', async () => {
    const devices = await Device.find({}).sort({ lastSeen: -1 });
    socket.emit('device_list', devices);
  });

  // Commandes Parent -> Enfant (Caméra, Micro, Écran)
  socket.on('command', (data) => {
    console.log(`📡 Commande ${data.action} -> ${data.targetId}`);
    io.to(data.targetId).emit('execute_command', data.action);
  });

  // Relayage WebRTC (Signaling)
  socket.on('signal', (data) => {
    io.to(data.target).emit('signal', data.payload);
  });

  socket.on('disconnect', async () => {
    console.log('🔌 Déconnexion:', socket.id);
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`🚀 Serveur ORIA lancé sur port ${PORT}`));
