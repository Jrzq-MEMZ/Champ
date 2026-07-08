#include "cam_handler.h"
#include "config.h"
#include "pins.h"
#include "Arduino.h"

bool camBegin() {
  esp_err_t err = esp_camera_init(&camera_config);
  if (err != ESP_OK) {
    Serial.printf("[CAM] init fail 0x%x\n", err);
    return false;
  }
  sensor_t* s = esp_camera_sensor_get();
  if (s) {
    s->set_vflip(s, 0);
    s->set_hmirror(s, 0);
  }
  Serial.println("[CAM] init ok");
  return true;
}

camera_fb_t* camCapture() {
  return esp_camera_fb_get();
}

void camRelease(camera_fb_t* fb) {
  if (fb) esp_camera_fb_return(fb);
}

bool camSetFramesize(framesize_t sz) {
  sensor_t* s = esp_camera_sensor_get();
  if (!s) return false;
  if (s->set_framesize(s, sz) != 0) return false;
  camera_config.frame_size = sz;
  return true;
}

bool camSetQuality(int q) {
  if (q < 4 || q > 63) return false;
  sensor_t* s = esp_camera_sensor_get();
  if (!s) return false;
  if (s->set_quality(s, q) != 0) return false;
  camera_config.jpeg_quality = q;
  return true;
}

framesize_t camGetFramesize() {
  return camera_config.frame_size;
}

int camGetQuality() {
  return camera_config.jpeg_quality;
}
