#pragma once
#ifdef MSHIELD_DEBUG
#include <android/log.h>
#define LOGI(...) ((void)__android_log_print(ANDROID_LOG_INFO, "MobileShield", __VA_ARGS__))
#else
#define LOGI(...) ((void)0)
#endif
