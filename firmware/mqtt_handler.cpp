#include "mqtt_handler.h"
#include "config.h"
#include "net_handler.h"
#include "cam_handler.h"
#include "ArduinoJson.h"
#include <time.h>

static WiFiClientSecure tlsClient;
static PubSubClient client(tlsClient);

static unsigned long lastReconnect = 0;
static int reconnectAttempt = 0;

static String topicFrame;
static String topicEnv;
static String topicStatus;
static String topicCmd;

volatile int g_cmdFps = 0;

static void onCmd(char* topic, byte* payload, unsigned int len) {
  StaticJsonDocument<256> doc;
  DeserializationError err = deserializeJson(doc, payload, len);
  if (err) {
    Serial.println("[MQTT] cmd parse fail");
    return;
  }
  if (doc.containsKey("framesize")) {
    int sz = doc["framesize"];
    if (sz >= 0 && sz <= 10) {
      if (camSetFramesize((framesize_t)sz)) {
        Serial.printf("[MQTT] framesize=%d\n", sz);
      }
    }
  }
  if (doc.containsKey("quality")) {
    int q = doc["quality"];
    if (camSetQuality(q)) {
      Serial.printf("[MQTT] quality=%d\n", q);
    }
  }
  if (doc.containsKey("fps")) {
    int f = doc["fps"];
    if (f >= 1 && f <= 15) {
      g_cmdFps = f;
      Serial.printf("[MQTT] fps=%d\n", f);
    }
  }
  if (doc.containsKey("led")) {
    int v = doc["led"];
    digitalWrite(LED_FLASH_PIN, v ? HIGH : LOW);
    Serial.printf("[MQTT] led=%d\n", v);
  }
}

static void ensureTopics() {
  topicFrame = "cam/" DEVICE_ID "/frame";
  topicEnv = "cam/" DEVICE_ID "/env";
  topicStatus = "cam/" DEVICE_ID "/status";
  topicCmd = "cam/" DEVICE_ID "/cmd";
}

static bool doConnect() {
  if (!netConnected()) return false;
  Serial.printf("[MQTT] connecting to %s:%d ... ", MQTT_HOST, MQTT_PORT);
  bool ok = client.connect(DEVICE_ID, MQTT_USER, MQTT_PASS,
                           topicStatus.c_str(), 1, true,
                           "{\"state\":\"offline\"}");
  if (ok) {
    client.subscribe(topicCmd.c_str(), 1);
    Serial.println("ok");
    reconnectAttempt = 0;
  } else {
    Serial.printf("fail state=%d\n", client.state());
  }
  return ok;
}

void mqttBegin() {
  ensureTopics();
  tlsClient.setCACert(MQTT_CA_CERT);
  client.setServer(MQTT_HOST, MQTT_PORT);
  client.setKeepAlive(MQTT_KEEPALIVE);
  client.setSocketTimeout(MQTT_TIMEOUT / 1000);
  client.setBufferSize(30000);
  client.setCallback(onCmd);
  doConnect();
}

void mqttLoop() {
  if (client.connected()) {
    client.loop();
    return;
  }
  client.loop();
  unsigned long now = millis();
  unsigned long backoff = MQTT_RECONNECT_MIN * (1 << min(reconnectAttempt, 5));
  if (backoff > MQTT_RECONNECT_MAX) backoff = MQTT_RECONNECT_MAX;
  if (now - lastReconnect < backoff) return;
  lastReconnect = now;
  reconnectAttempt++;
  doConnect();
}

bool mqttConnected() {
  return client.connected();
}

void mqttPublishFrame(const uint8_t* buf, size_t len) {
  if (!client.connected()) return;
  client.publish(topicFrame.c_str(), buf, len, false);
}

void mqttPublishEnv(const EnvData& d) {
  if (!client.connected()) return;
  StaticJsonDocument<192> doc;
  doc["deviceId"] = DEVICE_ID;
  doc["temperature"] = (int)(d.temperature * 10) / 10.0;
  doc["humidity"] = (int)(d.humidity * 10) / 10.0;
  doc["heatIndex"] = (int)(d.heatIndex * 10) / 10.0;
  doc["ts"] = (uint32_t)time(nullptr);
  char buf[192];
  serializeJson(doc, buf, sizeof(buf));
  client.publish(topicEnv.c_str(), buf, true);
}

void mqttPublishStatus(const String& state, float fps, size_t freeHeap, unsigned long uptime) {
  if (!client.connected()) return;
  StaticJsonDocument<256> doc;
  doc["deviceId"] = DEVICE_ID;
  doc["state"] = state;
  doc["ip"] = netGetIP();
  doc["rssi"] = netGetRssi();
  doc["uptime"] = uptime;
  doc["freeHeap"] = freeHeap;
  doc["fps"] = fps;
  doc["ts"] = (uint32_t)time(nullptr);
  char buf[256];
  serializeJson(doc, buf, sizeof(buf));
  client.publish(topicStatus.c_str(), buf, true);
}
