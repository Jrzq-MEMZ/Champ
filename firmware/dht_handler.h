#ifndef DHT_HANDLER_H
#define DHT_HANDLER_H

#include <Arduino.h>

struct EnvData {
  float temperature;
  float humidity;
  float heatIndex;
  unsigned long ts;
  bool valid;
};

void dhtBegin();
EnvData dhtRead();

#endif
