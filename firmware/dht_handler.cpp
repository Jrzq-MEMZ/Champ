#include "dht_handler.h"
#include "config.h"
#include <DHT.h>

static DHT dht(DHT_PIN, DHT11);

void dhtBegin() {
  dht.begin();
  Serial.println("[DHT] init ok");
}

EnvData dhtRead() {
  EnvData d;
  d.ts = millis();
  d.valid = false;

  float h = dht.readHumidity();
  float t = dht.readTemperature(false);

  if (isnan(h) || isnan(t)) {
    Serial.println("[DHT] read fail");
    return d;
  }

  d.temperature = t;
  d.humidity = h;
  d.heatIndex = dht.computeHeatIndex(t, h, false);
  d.valid = true;
  return d;
}
