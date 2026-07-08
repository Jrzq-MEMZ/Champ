'use strict';

const mqtt = require('mqtt');

const client = mqtt.connect(
  `mqtt://${process.env.MQTT_HOST || '127.0.0.1'}:${process.env.MQTT_PORT || 1883}`,
  {
    clientId: 'champ-api-' + Math.random().toString(16).slice(2, 8),
    username: process.env.MQTT_USER || 'api',
    password: process.env.MQTT_PASS || '',
    clean: true,
    keepalive: 30,
    reconnectPeriod: 3000,
    connectTimeout: 5000,
  }
);

const db = require('./db');

function handleEnv(deviceId, payload) {
  try {
    const d = JSON.parse(payload.toString());
    if (typeof d.temperature !== 'number') return;
    db.saveEnv({
      deviceId,
      temperature: d.temperature,
      humidity: d.humidity,
      heatIndex: d.heatIndex,
      ts: d.ts || Math.floor(Date.now() / 1000),
    });
  } catch (e) {
    console.error('[MQTT] env parse fail:', e.message);
  }
}

function handleStatus(deviceId, payload) {
  try {
    const d = JSON.parse(payload.toString());
    db.saveStatus({
      deviceId,
      state: d.state || 'unknown',
      ip: d.ip || '',
      rssi: d.rssi || 0,
      uptime: d.uptime || 0,
      freeHeap: d.freeHeap || 0,
      fps: d.fps || 0,
      ts: d.ts || Math.floor(Date.now() / 1000),
    });
  } catch (e) {
    console.error('[MQTT] status parse fail:', e.message);
  }
}

function handleFrame(deviceId, payload, packet) {
  const buf = Buffer.from(payload);
  db.saveFrame(deviceId, buf, Math.floor(Date.now() / 1000));
}

client.on('connect', () => {
  console.log('[MQTT] connected to broker');
  client.subscribe('cam/+/env',    { qos: 1 });
  client.subscribe('cam/+/status', { qos: 1 });
  client.subscribe('cam/+/frame',  { qos: 0 });
});

client.on('message', (topic, payload, packet) {
  const parts = topic.split('/');
  if (parts.length !== 3 || parts[0] !== 'cam') return;
  const deviceId = parts[1];
  const channel = parts[2];

  switch (channel) {
    case 'env':    handleEnv(deviceId, payload); break;
    case 'status': handleStatus(deviceId, payload); break;
    case 'frame':  handleFrame(deviceId, payload, packet); break;
  }
});

client.on('reconnect', () => console.log('[MQTT] reconnecting...'));
client.on('error', (err) => console.error('[MQTT] error:', err.message));
client.on('offline', () => console.warn('[MQTT] offline'));

module.exports = client;
