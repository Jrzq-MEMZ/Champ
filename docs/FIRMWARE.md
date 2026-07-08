# ESP32 固件烧录指南

## 1. 硬件清单

| 部件 | 数量 | 备注 |
|---|---|---|
| ESP32-CAM-MB（USB 版） | 1 | 带 USB 口，免 FTDI |
| OV3660 摄像头模组 | 1 | 引脚兼容 OV2640 |
| DHT11 模块（带板） | 1 | 自带 10kΩ 上拉 |
| 杜邦线 | 3 | VCC/DATA/GND |
| 小散热片（推荐） | 1 | 贴 OV3660 芯片上，可选但强烈建议 |

## 2. 接线

### 2.1 DHT11 → ESP32-CAM

```
DHT11       ESP32-CAM
─────       ─────────
VCC   ───>  3.3V
DATA  ───>  GPIO 12  (config.h: DHT_PIN)
GND   ───>  GND
```

> ⚠️ ESP32-CAM GPIO 引脚已大部分被摄像头占用，可用 GPIO 只有 **0、2、4、12、13、14、15、16**。
> 其中 **GPIO 0** 用于烧录模式，**GPIO 4** 是板载 LED 闪光灯，**GPIO 12** 选为 DHT 数据脚（避开摄像头 D0-D7/VSYNC/HREF/PCLK/XCLK/SCCB）。
> 若 GPIO 12 与你的摄像头冲突，可改为 GPIO 13 或 14（在 `config.h` 中同步修改）。

### 2.2 摄像头排线

OV3660 排线直接插入 ESP32-CAM 的摄像头 FPC 插座，扣紧即可。

## 3. 安装 Arduino IDE 环境

1. 下载 [Arduino IDE 2.x](https://www.arduino.cc/en/software)
2. 添加 ESP32 板支持：
   - 文件 → 首选项 → 附加开发板管理器网址
   - 填入：`https://espressif.github.io/arduino-esp32/package_esp32_index.json`
   
   > ⚠️ 注意 URL 必须带 `gh-pages` 分支或用 CDN 链接。以下写法都会 404：
   > - ❌ `https://raw.githubusercontent.com/espressif/arduino-esp32/package_esp32_index.json`（缺分支）
   > - ❌ `...package_esp32_index_json`（下划线，应为 `.json`）
   > 
   > 若 `espressif.github.io` 也访问不了（国内网络），用极狐镜像：
   > `https://jihulab.com/esp-mirror/espressif/arduino-esp32/-/raw/gh-pages/package_esp32_index_cn.json`
3. **完全退出 IDE 再重开**（IDE 2.x 已知 Bug：加 URL 后不重启不会下载索引）
4. 工具 → 开发板 → 开发板管理器 → 搜索 `esp32` → 安装 **esp32 by Espressif Systems**（版本 3.0.0+）
   > 如果 Boards Manager 搜不到但 `packages/esp32` 已存在，是 IDE 2.x 搜索显示 bug，不影响使用。直接去 Tools > Board > esp32 > AI Thinker ESP32-CAM 选板即可。
5. 工具 → 开发板 → 选择 **AI Thinker ESP32-CAM**

## 4. 安装库

工具 → 库管理器，依次搜索并安装：

| 库名 | 版本建议 | 用途 |
|---|---|---|
| `PubSubClient` | 2.8+ | MQTT 客户端 |
| `DHT sensor library` (by Adafruit) | 1.4.6+ | DHT11 驱动 |
| `ArduinoJson` | 7.x | JSON 序列化 |

> 摄像头驱动 `esp_camera.h` 已随 ESP32 板包自带，无需单独装。

## 5. 修改配置

打开 `firmware/firmware.ino`（同目录会自动加载其它 .h/.cpp），编辑 `config.h`：

```c
#define DEVICE_ID       "esp32cam-01"
#define WIFI_SSID       "你的WiFi名"
#define WIFI_PASSWORD   "你的WiFi密码"
#define MQTT_HOST       "your-domain.com"      // VPS 域名
#define MQTT_PORT       8883
#define MQTT_USER       "esp32cam"
#define MQTT_PASS       "esp32cam_pass_change_me"   // 部署时设的
```

### 5.1 填 CA 证书

`MQTT_CA_CERT` 填 Let's Encrypt 的 ISRG Root X1 或 R3 中级证书 PEM，确保 `\n` 拼接。

最简方法：用 Mozilla CA bundle 里的 ISRG Root X1：

```bash
# 在 VPS 上执行，把输出复制到 config.h 的 MQTT_CA_CERT
openssl s_client -connect your-domain.com:8883 -showcerts </dev/null 2>/dev/null \
  | awk '/-----BEGIN CERTIFICATE-----/{f=1} f{print} /-----END CERTIFICATE-----/{f=0}' \
  | tail -20
```

或者直接用 Let's Encrypt 根证书 [ISRG Root X1](https://letsencrypt.org/certificates/)（推荐 ESP32 用根证书，长期有效）。

## 6. 烧录

### 6.1 ESP32-CAM-MB（USB 版）

1. USB 线连电脑
2. 工具 → 端口 → 选对应 COM 口
3. 工具 → 上传速率 → `115200`
4. 点击上传按钮（→）

> ESP32-CAM-MB 板载 USB-UPI 芯片自动处理 GPIO 0，**无需**手动接 GND。

### 6.2 老 ESP32-CAM（无 USB）

需 FTDI/CP2102 USB-TTL：
- FTDI TX → ESP32-CAM RX（GPIO 3/U0R）
- FTDI RX → ESP32-CAM TX（GPIO 1/U0T）
- FTDI 5V → ESP32-CAM 5V
- GND 共地
- **GPIO 0 → GND**（烧录模式）
- 按复位键
- 上传完成后断开 GPIO 0，再按复位进入运行

## 7. 验证

1. 串口监视器（波特率 115200）看到：
   ```
   ==== ESP32-CAM 启动 ====
   [CAM] init ok
   [DHT] init ok
   [NET] connecting to YOUR_WIFI...
   [NET] connected, IP=192.168.x.x RSSI=-55
   [NTP] sync.....
   [MQTT] connecting to your-domain.com:8883 ... ok
   [DHT] T=25.0C H=60.0% HI=26.2
   ```
2. 在 VPS 上监听：
   ```bash
   mosquitto_sub -h 127.0.0.1 -p 1883 -u api -P your_api_pass -t 'cam/#' -v
   ```
   应看到 `cam/esp32cam-01/env` JSON 和连续的 `cam/esp32cam-01/frame` 二进制。

## 8. OV3660 降温注意事项

- 默认 VGA @ 5fps @ Q12，运行温度可控（约 50-60°C）
- 若 App 下发更高参数（SVGA+15fps+Q6），OV3660 可能 5 分钟内死机
- 死机后看门狗会自动复位（30 秒）
- **强烈建议**贴一片小铜散热片在 OV3660 芯片上（1 元钱，效果显著）

## 9. 常见问题

| 现象 | 原因 | 解决 |
|---|---|---|
| 摄像头初始化失败 `0x105` | 排线没插紧 / GPIO 12 冲突 | 重插排线；换 DHT_PIN |
| WiFi 连不上 | 5GHz WiFi / 密码错 | ESP32 只支持 2.4GHz |
| MQTT 连接 state=-2 | CA 证书不对 | 重填 ISRG Root X1 |
| MQTT 连接 state=5 | 用户名密码错 / 账号没 ACL 权限 | 检查 mosquitto/passwd |
| 帧卡住 / 黑屏 | OV3660 过热 | 降帧降画质，加散热片 |
| DHT11 读 NaN | 接线松 / 上拉缺失 | 换 GPIO 13/14 试试 |
