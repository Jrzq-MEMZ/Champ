#ifndef CONFIG_H
#define CONFIG_H

// ==================== 设备身份 ====================
#define DEVICE_ID "esp32cam-01"

// ==================== WiFi ====================
#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"

// ==================== MQTT ====================
#define MQTT_HOST "your-domain.com"
#define MQTT_PORT 8883
#define MQTT_USER "esp32cam"
#define MQTT_PASS "your_mqtt_password"
#define MQTT_KEEPALIVE 30
#define MQTT_TIMEOUT 5000
#define MQTT_RECONNECT_MIN 2000
#define MQTT_RECONNECT_MAX 60000

// ==================== MQTT CA 证书 ====================
// Let's Encrypt R3 或你 VPS 的 CA 证书，PEM 内容（去换行）
#define MQTT_CA_CERT \
"-----BEGIN CERTIFICATE-----\n" \
"YOUR_CA_CERT_HERE\n" \
"-----END CERTIFICATE-----\n"

// ==================== DHT11 ====================
#define DHT_PIN 12
#define DHT_TYPE DHT11
#define DHT_INTERVAL_MS 10000

// ==================== 摄像头默认参数（OV3660 软件降温）====================
#define CAM_XCLK_FREQ 10000000
#define CAM_FRAMESIZE_DEFAULT FRAMESIZE_VGA
#define CAM_FPS_DEFAULT 5
#define CAM_QUALITY_DEFAULT 12
#define CAM_FB_COUNT 1

// ==================== 心跳 ====================
#define STATUS_INTERVAL_MS 60000

// ==================== 看门狗 ====================
#define WDT_TIMEOUT_S 30

#endif
