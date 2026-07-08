'use strict';

const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

const dbPath = process.env.DB_PATH || path.join(__dirname, '../data/champ.db');
fs.mkdirSync(path.dirname(dbPath), { recursive: true });

const db = new Database(dbPath);
db.pragma('journal_mode = WAL');
db.pragma('synchronous = NORMAL');

db.exec(`
CREATE TABLE IF NOT EXISTS env_log (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  deviceId  TEXT    NOT NULL,
  temperature REAL  NOT NULL,
  humidity    REAL  NOT NULL,
  heatIndex   REAL  NOT NULL,
  ts        INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_env_device_ts ON env_log(deviceId, ts DESC);

CREATE TABLE IF NOT EXISTS device_status (
  deviceId  TEXT    PRIMARY KEY,
  state     TEXT,
  ip        TEXT,
  rssi      INTEGER,
  uptime    INTEGER,
  freeHeap  INTEGER,
  fps       REAL,
  lastSeen  INTEGER
);

CREATE TABLE IF NOT EXISTS latest_frame (
  deviceId  TEXT    PRIMARY KEY,
  jpeg      BLOB,
  ts        INTEGER
);
`);

const stmtInsertEnv = db.prepare(
  `INSERT INTO env_log (deviceId, temperature, humidity, heatIndex, ts)
   VALUES (@deviceId, @temperature, @humidity, @heatIndex, @ts)`
);
const stmtUpsertStatus = db.prepare(
  `INSERT INTO device_status (deviceId, state, ip, rssi, uptime, freeHeap, fps, lastSeen)
   VALUES (@deviceId, @state, @ip, @rssi, @uptime, @freeHeap, @fps, @ts)
   ON CONFLICT(deviceId) DO UPDATE SET
     state=excluded.state, ip=excluded.ip, rssi=excluded.rssi,
     uptime=excluded.uptime, freeHeap=excluded.freeHeap, fps=excluded.fps,
     lastSeen=excluded.lastSeen`
);
const stmtUpsertFrame = db.prepare(
  `INSERT INTO latest_frame (deviceId, jpeg, ts) VALUES (@deviceId, @jpeg, @ts)
   ON CONFLICT(deviceId) DO UPDATE SET jpeg=excluded.jpeg, ts=excluded.ts`
);

function saveEnv(record) {
  stmtInsertEnv.run(record);
}

function saveStatus(record) {
  stmtUpsertStatus.run(record);
}

function saveFrame(deviceId, jpegBuf, ts) {
  stmtUpsertFrame.run({ deviceId, jpeg: jpegBuf, ts });
}

function getEnvHistory(deviceId, hours = 24) {
  const since = Math.floor(Date.now() / 1000) - hours * 3600;
  return db.prepare(
    `SELECT temperature, humidity, heatIndex, ts
     FROM env_log
     WHERE deviceId = ? AND ts >= ?
     ORDER BY ts ASC`
  ).all(deviceId, since);
}

function getLatestEnv(deviceId) {
  return db.prepare(
    `SELECT temperature, humidity, heatIndex, ts
     FROM env_log WHERE deviceId = ?
     ORDER BY ts DESC LIMIT 1`
  ).get(deviceId);
}

function getLatestFrame(deviceId) {
  return db.prepare(
    `SELECT jpeg, ts FROM latest_frame WHERE deviceId = ?`
  ).get(deviceId);
}

function listDevices() {
  return db.prepare(
    `SELECT ds.*, le.temperature, le.humidity, le.heatIndex
     FROM device_status ds
     LEFT JOIN env_log le ON le.id = (
       SELECT id FROM env_log WHERE deviceId = ds.deviceId ORDER BY ts DESC LIMIT 1
     )`
  ).all();
}

function pruneOldEnv(daysToKeep = 30) {
  const cutoff = Math.floor(Date.now() / 1000) - daysToKeep * 86400;
  return db.prepare(`DELETE FROM env_log WHERE ts < ?`).run(cutoff);
}

module.exports = {
  db,
  saveEnv,
  saveStatus,
  saveFrame,
  getEnvHistory,
  getLatestEnv,
  getLatestFrame,
  listDevices,
  pruneOldEnv,
};
