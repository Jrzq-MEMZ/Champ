# ESP32-CAM 视频温湿度检测系统

基于 ESP32-CAM + OV3660 + DHT11 + VPS + Flutter App 的远程视频与环境监测系统。

## 系统架构

```
┌──────────────┐    MQTT/TLS     ┌──────────────────────────┐    HTTPS/MQTT-WS   ┌──────────────┐
│  ESP32-CAM   │ ──────────────> │          VPS             │ <────────────────> │  Flutter App │
│  OV3660      │  cam/{id}/frame │  Mosquitto Broker        │  cam/{id}/frame    │              │
│  DHT11       │  cam/{id}/env   │  Node.js API + SQLite    │  cam/{id}/env      │  实时视频     │
│  (家庭WiFi)  │  cam/{id}/cmd <─│  Nginx (TLS 反代)        │  REST /api/history │  温湿度曲线   │
└──────────────┘                 └──────────────────────────┘                     └──────────────┘
```

## 目录结构

```
Champ/
├── firmware/          ESP32 Arduino 固件
├── vps/               VPS 服务端
│   ├── mosquitto/     MQTT broker 配置
│   ├── nginx/         Nginx 反代配置
│   └── api/           Node.js 后端 (Express + mqtt.js + SQLite)
├── app/               Flutter 手机客户端
└── docs/              文档（架构/接线/部署/烧录）
```

## 数据流

1. **ESP32 → VPS（MQTT 上行，TLS 8883）**
   - `cam/{deviceId}/frame`：JPEG 视频帧（二进制，QoS 0）
   - `cam/{deviceId}/env`：温湿度 JSON（QoS 1，每 10 秒）
   - `cam/{deviceId}/status`：设备上线/下线/心跳（QoS 1）

2. **VPS → ESP32（MQTT 下行）**
   - `cam/{deviceId}/cmd`：参数调整 JSON（分辨率/帧率/质量）

3. **VPS → App（MQTT over WebSocket，TLS 443/mqtt）**
   - 转发 `cam/{deviceId}/frame` 和 `cam/{deviceId}/env`

4. **App → VPS（HTTPS REST）**
   - `GET /api/env/history?hours=24`：历史温湿度
   - `GET /api/devices`：设备列表
   - `GET /api/snapshot/{deviceId}`：最新一帧 JPEG

## 技术栈

| 层 | 技术 |
|---|---|
| 固件 | Arduino IDE / esp_camera / PubSubClient / DHT sensor library |
| Broker | Mosquitto 2.x (TLS 8883 + WSS 9443) |
| 后端 | Node.js 20 / Express / mqtt.js / better-sqlite3 |
| 反代 | Nginx + Let's Encrypt |
| 数据库 | SQLite 3 |
| App | Flutter 3.x / mqtt_client / fl_chart / flutter_local_notifications |

## 快速开始

见 [docs/DEPLOY.md](docs/DEPLOY.md) 完整部署指南。

1. 烧录固件：见 [docs/FIRMWARE.md](docs/FIRMWARE.md)
2. 部署 VPS：见 [docs/DEPLOY.md](docs/DEPLOY.md)
3. 构建 App：见 [docs/APP.md](docs/APP.md)

## 已确认需求

- 硬件：ESP32-CAM-MB（USB 版）/ OV3660（无散热片，软件降温）/ DHT11
- 固件：Arduino IDE
- 传输：MQTT 上行（家庭 WiFi 无公网 IP，ESP32 主动外连）
- VPS：Ubuntu 2GB+ / 有域名 / Mosquitto 自建 / SQLite
- App：Flutter 中文 / 实时视频 + 温湿度显示 + 历史曲线 + 通知栏常驻
- 单台摄像头，预留多设备扩展
- 视频质量 App 可调（分辨率/帧率/质量）
- 个人长期使用，需稳定自动重连
