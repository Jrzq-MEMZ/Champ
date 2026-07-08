#ifndef PINS_H
#define PINS_H

#include "esp_camera.h"
#include "config.h"

// ESP32-CAM-MB (AI-Thinker 引脚映射，兼容 OV2640/OV3660)
static camera_config_t camera_config = {
    .pin_pwdn = 32,
    .pin_reset = -1,
    .pin_xclk = 0,
    .pin_sccb_sda = 26,
    .pin_sccb_scl = 27,
    .pin_d7 = 35,
    .pin_d6 = 34,
    .pin_d5 = 39,
    .pin_d4 = 36,
    .pin_d3 = 21,
    .pin_d2 = 19,
    .pin_d1 = 18,
    .pin_d0 = 5,
    .pin_vsync = 25,
    .pin_href = 23,
    .pin_pclk = 22,
    .xclk_freq_hz = CAM_XCLK_FREQ,
    .ledc_channel = LEDC_CHANNEL_0,
    .ledc_timer = LEDC_TIMER_0,
    .pixel_format = PIXFORMAT_JPEG,
    .frame_size = CAM_FRAMESIZE_DEFAULT,
    .jpeg_quality = CAM_QUALITY_DEFAULT,
    .fb_count = CAM_FB_COUNT,
    .grab_mode = CAMERA_GRAB_WHEN_EMPTY,
};

#endif
