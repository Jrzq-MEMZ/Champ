'use strict';

const express = require('express');
const compression = require('compression');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');

const db = require('./db');
require('./mqttClient');

const app = express();
const PORT = process.env.HTTP_PORT || 3000;
const API_TOKEN = process.env.API_TOKEN || 'champ_default_token_change_me';
const DOMAIN = process.env.DOMAIN || 'localhost';

app.use(compression());
app.use(cors());
app.use(express.json());
app.use(morgan('combined'));

// Bearer Token 鉴权
function auth(req, res, next) {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
  if (token !== API_TOKEN) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  next();
}

// 健康检查（无需鉴权）
app.get('/api/health', (req, res) => {
  res.json({ ok: true, time: Math.floor(Date.now() / 1000) });
});

// 设备列表
app.get('/api/devices', auth, (req, res) => {
  const devices = db.listDevices();
  res.json({
    devices: devices.map(d => ({
      deviceId: d.deviceId,
      state: d.state,
      ip: d.ip,
      rssi: d.rssi,
      uptime: d.uptime,
      freeHeap: d.freeHeap,
      fps: d.fps,
      lastSeen: d.lastSeen,
      temperature: d.temperature,
      humidity: d.humidity,
      heatIndex: d.heatIndex,
    })),
  });
});

// 温湿度历史
app.get('/api/env/history', auth, (req, res) => {
  const deviceId = req.query.deviceId || 'esp32cam-01';
  const hours = Math.min(parseInt(req.query.hours || '24', 10), 720);
  const rows = db.getEnvHistory(deviceId, hours);
  res.json({
    deviceId,
    hours,
    points: rows.map(r => ({
      temperature: r.temperature,
      humidity: r.humidity,
      heatIndex: r.heatIndex,
      ts: r.ts,
    })),
  });
});

// 最新温湿度
app.get('/api/env/latest', auth, (req, res) => {
  const deviceId = req.query.deviceId || 'esp32cam-01';
  const row = db.getLatestEnv(deviceId);
  if (!row) return res.status(404).json({ error: 'no data' });
  res.json(row);
});

// 最新一帧快照（JPEG，无需鉴权给 Nginx 缓存，或加 auth 看你需求）
app.get('/api/snapshot/:deviceId', auth, (req, res) => {
  const row = db.getLatestFrame(req.params.deviceId);
  if (!row || !row.jpeg) return res.status(404).send('no frame');
  res.type('image/jpeg');
  res.set('Cache-Control', 'no-store');
  res.send(row.jpeg);
});

// 清理旧数据（可定期调用）
app.post('/api/maintenance/prune', auth, (req, res) => {
  const days = parseInt(req.query.days || '30', 10);
  const result = db.pruneOldEnv(days);
  res.json({ pruned: result.changes, days });
});

// 静态文件（如需提供 Web 端看板，可选）
app.use('/web', express.static(path.join(__dirname, '../public')));

// 404
app.use((req, res) => res.status(404).json({ error: 'not found' }));

// 错误处理
app.use((err, req, res, next) => {
  console.error('[API] error:', err);
  res.status(500).json({ error: 'internal' });
});

app.listen(PORT, '127.0.0.1', () => {
  console.log(`[API] listening on 127.0.0.1:${PORT}`);
  console.log(`[API] domain: ${DOMAIN}`);
  console.log(`[API] token:  ${API_TOKEN ? '已设置' : '未设置'}`);
});
