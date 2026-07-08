#ifndef CAM_HANDLER_H
#define CAM_HANDLER_H

#include "esp_camera.h"

bool camBegin();
camera_fb_t* camCapture();
void camRelease(camera_fb_t* fb);
bool camSetFramesize(framesize_t sz);
bool camSetQuality(int q);
framesize_t camGetFramesize();
int camGetQuality();

#endif
