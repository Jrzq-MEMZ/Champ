#ifndef MQTT_HANDLER_H
#define MQTT_HANDLER_H

#include <Arduino.h>
#include <PubSubClient.h>
#include <WiFiClientSecure.h>
#include "dht_handler.h"

void mqttBegin();
void mqttLoop();
bool mqttConnected();
void mqttPublishFrame(const uint8_t* buf, size_t len);
void mqttPublishEnv(const EnvData& d);
void mqttPublishStatus(const String& state, float fps, size_t freeHeap, unsigned long uptime);

// App 下发的 fps（0 表示未设置，用默认）；firmware.ino 读取此值
extern volatile int g_cmdFps;

#endif
