# 架构设计

## 1. 总体架构

```
家庭内网                          公网                          移动网络
┌─────────────────┐         ┌──────────────────────┐         ┌─────────────────┐
│  ESP32-CAM-MB   │         │      VPS (Ubuntu)    │         │   Flutter App   │
│                 │  MQTT   │                      │  WSS    │                 │
│  OV3660 摄像头  │ TLS     │  ┌────────────────┐  │ MQTT    │  视频画面       │
│  DHT11 传感器   │ 8883    │  │  Mosquitto     │  │ 9443    │  温湿度卡片     │
│  WiFi STA 模式  │ ──────> │  │  Broker        │  │ <─────> │  历史曲线图     │
│                 │         │  └────────────────┘  │         │  通知栏常驻     │
│  软件降温:      │         │  ┌────────────────┐  │  HTTPS  │  参数调节面板   │
│  XCLK 10MHz     │         │  │  Node.js API   │  │ REST    │                 │
│  VGA @5fps 默认 │         │  │  Express       │  │ <─────> │                 │
│  JPEG q=12      │         │  │  SQLite        │  │         │                 │
│                 │         │  └────────────────┘  │         │                 │
│  自动重连       │         │  ┌────────────────┐  │         │                 │
│  Watchdog       │         │  │  Nginx (TLS)   │  │         │                 │
│                 │         │  │  反向代理      │  │         │                 │
└─────────────────┘         │  └────────────────┘  │         │                 │
                            └──────────────────────┘         └─────────────────┘
```

## 2. MQTT Topic 设计

### 2.1 命名规范

```
cam/{deviceId}/{channel}
```

- `deviceId`：设备 ID，默认 `esp32cam-01`，可在固件 `config.h` 改
- 预留多设备：`esp32cam-02`、`esp32cam-03`...

### 2.2 Topic 列表

| Topic | 方向 | Payload | QoS | 频率 | 说明 |
|---|---|---|---|---|---|
| `cam/{id}/frame` | ESP32→Broker→App | 二进制 JPEG | 0 | 按帧率 | 视频帧，丢弃旧帧 |
| `cam/{id}/env` | ESP32→Broker→App | JSON | 1 | 10s | 温湿度 |
| `cam/{id}/status` | ESP32→Broker | JSON | 1 | 60s + 上下线 | 心跳 |
| `cam/{id}/cmd` | App→Broker→ESP32 | JSON | 1 | 按需 | 参数调整 |

### 2.3 Payload 格式

**`cam/{id}/env`**
```json
{
  "deviceId": "esp32cam-01",
  "temperature": 25.0,
  "humidity": 60.0,
  "heatIndex": 26.2,
  "ts": 1720000000
}
```

**`cam/{id}/status`**
```json
{
  "deviceId": "esp32cam-01",
  "state": "online",
  "ip": "192.168.1.100",
  "rssi": -55,
  "uptime": 3600,
  "freeHeap": 150000,
  "fps": 5.0,
  "ts": 1720000000
}
```

**`cam/{id}/cmd`**
```json
{
  "framesize": 6,
  "fps": 5,
  "quality": 12,
  "ts": 1720000000
}
```
- `framesize`：0=QVGA,4=CIF,5=VGA,6=SVGA,7=HD（OV3660 降帧用）
- `fps`：1-15
- `quality`：10-31（数值越大画质越差、文件越小、越凉）

## 3. 端口规划

| 端口 | 协议 | 服务 | 对外 | 说明 |
|---|---|---|---|---|
| 8883 | MQTT/TLS | Mosquitto | 是 | ESP32 直连（TLS + 用户名密码） |
| 443 | HTTPS + WSS | Nginx | 是 | REST API + MQTT/WebSocket 反代 |
| 80 | HTTP | Nginx | 是 | 仅跳转 HTTPS + ACME 验证 |
| 1883 | MQTT | Mosquitto | 否 | 仅 127.0.0.1，Node.js 后端订阅用 |
| 9400 | MQTT/WS | Mosquitto | 否 | 仅 127.0.0.1，Nginx 反代到此 |
| 3000 | HTTP | Node.js API | 否 | 仅 127.0.0.1，Nginx 反代到 443 |

## 4. OV3660 软件降温方案

OV3660 在 OV2640 供电板（2.8V）上内部 1.5V 稳压器过载发热。软件策略：

| 参数 | 默认值 | 说明 |
|---|---|---|
| XCLK | 10MHz（非 20MHz） | 降一半时钟，发热显著降低 |
| framesize | VGA 640x480 | 默认 VGA，不用 SVGA/HD |
| fps | 5 | 默认 5fps，App 可调 1-15 |
| jpeg_quality | 12 | 压缩更狠，文件小、编码器负载低 |
| fb_count | 1 | 单缓冲省内存、减并发 |
| grab_mode | WHEN_EMPTY | 不堆积帧 |

App 可下发 cmd 动态调 `framesize`/`fps`/`quality`，过热时手动降级。

## 5. DHT11 接线

| DHT11 | ESP32-CAM GPIO |
|---|---|
| VCC | 3.3V |
| DATA | GPIO 12（`config.h` 可改） |
| GND | GND |

- 采样间隔 10 秒（DHT11 最小 1 秒，留余量）
- 10kΩ 上拉电阻（模块板通常自带）

## 6. 安全

- Mosquitto：TLS + 用户名密码（`esp32cam` / App 各一份凭证）
- 不允许匿名连接
- Node.js API：Bearer Token（简单口令，个人使用够用）
- Nginx：Let's Encrypt HTTPS

## 7. 可靠性

- ESP32：WiFi/MQTT 断线指数退避重连，看门狗喂狗，死机自动复位
- Node.js：MQTT 自动重连，进程 systemd 管理，崩溃自重启
- Mosquitto：持久化 `persistence true`，systemd 管理
- Flutter：MQTT 自动重连，断线提示 UI，通知栏服务常驻
