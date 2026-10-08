#include <jni.h>

#ifndef MS_VERSION
#define MS_VERSION "0.0.0-unknown"
#endif

#define MS_EXPORT __attribute__((visibility("default")))

extern "C" {

MS_EXPORT jint JNI_OnLoad(JavaVM *vm, void *) {
    JNIEnv *env = nullptr;
    if (vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
        return JNI_ERR;
    }
    return JNI_VERSION_1_6;
}

MS_EXPORT jstring JNICALL Java_io_mobileshield_MobileShield_nativeVersion(JNIEnv *env, jclass) {
    return env->NewStringUTF(MS_VERSION);
}

}
