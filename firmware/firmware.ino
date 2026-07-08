/******************************************************************************
 * ESP32-CAM 视频温湿度检测系统 - 固件主程序
 * 硬件: ESP32-CAM-MB + OV3660 + DHT11
 * 架构: WiFi STA -> MQTT/TLS 上行到 VPS
 ******************************************************************************/
#include "config.h"
#include "cam_handler.h"
#include "dht_handler.h"
#include "net_handler.h"
#include "mqtt_handler.h"
#include <esp_task_wdt.h>
#include <time.h>
#include "esp_idf_version.h"

static unsigned long lastDht = 0;
static unsigned long lastStatus = 0;
static unsigned long lastFrame = 0;
static int frameIntervalMs = 1000 / CAM_FPS_DEFAULT;
static unsigned long frameCount = 0;
static unsigned long fpsTimer = 0;
static float currentFps = 0;

static void syncTime() {
  configTime(8 * 3600, 0, "ntp.aliyun.com", "pool.ntp.org");
  Serial.print("[NTP] sync");
  for (int i = 0; i < 20 && time(nullptr) < 1700000000; i++) {
    Serial.print(".");
    delay(500);
  }
  Serial.println();
}

static void applyFps(int fps) {
  if (fps < 1) fps = 1;
  if (fps > 15) fps = 15;
  frameIntervalMs = 1000 / fps;
}

void setup() {
  Serial.begin(115200);
  Serial.setDebugOutput(false);
  delay(500);
  Serial.println("\n==== ESP32-CAM 启动 ====");

#if ESP_IDF_VERSION_MAJOR >= 5
  esp_task_wdt_config_t wdt_config = {
    .timeout_ms = WDT_TIMEOUT_S * 1000,
    .idle_core_mask = BIT(0) | BIT(1),
    .trigger_panic = true,
  };
  esp_task_wdt_init(&wdt_config);
#else
  esp_task_wdt_init(WDT_TIMEOUT_S, true);
#endif
  esp_task_wdt_add(NULL);

  if (!camBegin()) {
    Serial.println("[BOOT] camera fail, reboot in 5s");
    delay(5000);
    ESP.restart();
  }
  dhtBegin();
  netBegin();
  syncTime();
  mqttBegin();

  fpsTimer = millis();
  esp_task_wdt_reset();
}

void loop() {
  esp_task_wdt_reset();
  netLoop();
  mqttLoop();

  unsigned long now = millis();

  // 处理 App 下发的 fps 调整
  if (g_cmdFps > 0) {
    applyFps(g_cmdFps);
    g_cmdFps = 0;
  }

  // 视频帧（仅在 MQTT 在线时发）
  if (mqttConnected() && now - lastFrame >= (unsigned long)frameIntervalMs) {
    lastFrame = now;
    camera_fb_t* fb = camCapture();
    if (fb) {
      mqttPublishFrame(fb->buf, fb->len);
      camRelease(fb);
      frameCount++;
    }
  }

  // FPS 统计
  if (now - fpsTimer >= 5000) {
    currentFps = frameCount * 1000.0 / (now - fpsTimer);
    frameCount = 0;
    fpsTimer = now;
  }

  // 温湿度（10s）
  if (mqttConnected() && now - lastDht >= DHT_INTERVAL_MS) {
    lastDht = now;
    EnvData d = dhtRead();
    if (d.valid) {
      mqttPublishEnv(d);
      Serial.printf("[DHT] T=%.1fC H=%.1f%% HI=%.1f\n",
                    d.temperature, d.humidity, d.heatIndex);
    }
  }

  // 心跳状态（60s）
  if (mqttConnected() && now - lastStatus >= STATUS_INTERVAL_MS) {
    lastStatus = now;
    mqttPublishStatus("online", currentFps, ESP.getFreeHeap(), millis() / 1000);
  }

  delay(1);
}
