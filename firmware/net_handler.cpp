#include "net_handler.h"
#include "config.h"
#include <WiFi.h>

static unsigned long lastReconnect = 0;

bool netBegin() {
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.setHostname(DEVICE_ID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.printf("[NET] connecting to %s", WIFI_SSID);

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
    Serial.print(".");
    delay(300);
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[NET] connected, IP=%s RSSI=%d\n",
                  netGetIP().c_str(), netGetRssi());
    return true;
  }
  Serial.println("\n[NET] connect fail");
  return false;
}

bool netConnected() {
  return WiFi.status() == WL_CONNECTED;
}

void netLoop() {
  if (netConnected()) return;
  if (millis() - lastReconnect < 5000) return;
  lastReconnect = millis();
  Serial.println("[NET] reconnecting...");
  WiFi.reconnect();
}

String netGetIP() {
  return WiFi.localIP().toString();
}

int8_t netGetRssi() {
  return WiFi.RSSI();
}
