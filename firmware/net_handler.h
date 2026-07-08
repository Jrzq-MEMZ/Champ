#ifndef NET_HANDLER_H
#define NET_HANDLER_H

#include <Arduino.h>

bool netBegin();
bool netConnected();
void netLoop();
String netGetIP();
int8_t netGetRssi();

#endif
