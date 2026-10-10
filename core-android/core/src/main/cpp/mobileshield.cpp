#include <jni.h>

#include <string>
#include <vector>

#include "detectors/AntiDebug.h"
#include "detectors/CrossReadings.h"
#include "detectors/Registry.h"
#include "detectors/IDetector.h"
#include "detectors/RootDetect.h"
#include "policy/Policy.h"
#include "util/Log.h"

#ifndef MS_VERSION
#define MS_VERSION "0.0.0-unknown"
#endif

#define MS_EXPORT __attribute__((visibility("default")))

namespace {

constexpr const char *kBridgeClass = "io/mobileshield/internal/NativeBridge";

std::string toStd(JNIEnv *env, jstring s) {
    if (s == nullptr) return std::string();
    const char *utf = env->GetStringUTFChars(s, nullptr);
    if (utf == nullptr) return std::string();
    std::string out(utf);
    env->ReleaseStringUTFChars(s, utf);
    return out;
}

jstring nativeVersion(JNIEnv *env, jclass) { return env->NewStringUTF(MS_VERSION); }

void nativeConfigure(JNIEnv *env, jclass, jintArray actions, jdouble threshold, jlong minDelay, jlong maxDelay,
                     jboolean prod) try {
    if (actions == nullptr || env->GetArrayLength(actions) != ms::kCategoryCount) return;
    jint values[ms::kCategoryCount];
    env->GetIntArrayRegion(actions, 0, ms::kCategoryCount, values);
    ms::PolicyConfig config{};
    for (int i = 0; i < ms::kCategoryCount; ++i) config.actions[i] = values[i];
    config.blockThreshold = threshold;
    config.killDelayMinMs = static_cast<int64_t>(minDelay);
    config.killDelayMaxMs = static_cast<int64_t>(maxDelay);
    config.prodFloor = prod;
    ms::Policy::instance().apply(config);
} catch (...) {
}

// A C++ exception must never unwind into the JVM (it aborts the host).
jint nativeDecide(JNIEnv *env, jclass, jint category, jstring id, jdouble confidence) try {
    return ms::Policy::instance().decide(category, toStd(env, id).c_str(), confidence);
} catch (...) {
    return ms::kReport;
}

jboolean nativeIsBlocked(JNIEnv *, jclass) { return ms::Policy::instance().isBlocked(); }

jobjectArray nativeCatalog(JNIEnv *env, jclass) {
    const auto &all = ms::detectors();
    jclass stringClass = env->FindClass("java/lang/String");
    if (stringClass == nullptr) return nullptr;
    jobjectArray out = env->NewObjectArray(static_cast<jsize>(all.size()), stringClass, nullptr);
    if (out == nullptr) return nullptr;
    for (size_t i = 0; i < all.size(); i++) {
        jstring id = env->NewStringUTF(all[i]->id());
        env->SetObjectArrayElement(out, static_cast<jsize>(i), id);
        env->DeleteLocalRef(id);
    }
    return out;
}

jintArray nativeCatalogCategories(JNIEnv *env, jclass) {
    const auto &all = ms::detectors();
    std::vector<jint> categories;
    for (const ms::IDetector *d : all) categories.push_back(d->category());
    jintArray out = env->NewIntArray(static_cast<jsize>(categories.size()));
    if (out != nullptr) env->SetIntArrayRegion(out, 0, static_cast<jsize>(categories.size()), categories.data());
    return out;
}

jfloatArray nativeRunChecks(JNIEnv *env, jclass, jobjectArray disabled) try {
    std::vector<std::string> off;
    if (disabled != nullptr) {
        const jsize n = env->GetArrayLength(disabled);
        for (jsize i = 0; i < n; i++) {
            jstring s = static_cast<jstring>(env->GetObjectArrayElement(disabled, i));
            off.push_back(toStd(env, s));
            if (s != nullptr) env->DeleteLocalRef(s);
        }
    }
    const std::vector<float> results = ms::runAll(off);
    jfloatArray out = env->NewFloatArray(static_cast<jsize>(results.size()));
    if (out != nullptr) env->SetFloatArrayRegion(out, 0, static_cast<jsize>(results.size()), results.data());
    return out;
} catch (...) {
    return nullptr;
}

// [suPresent "1"/"0", main-thread TracerPid, native version, mapped APK dir or ""]
jobjectArray nativeCrossReadings(JNIEnv *env, jclass, jstring packageName) try {
    const std::string values[4] = {
        ms::RootSuPaths::suPresent() ? "1" : "0",
        std::to_string(ms::DebuggerTracerPid::mainTracerPid()),
        MS_VERSION,
        ms::mappedApkDir(toStd(env, packageName)),
    };
    jclass stringClass = env->FindClass("java/lang/String");
    if (stringClass == nullptr) return nullptr;
    jobjectArray out = env->NewObjectArray(4, stringClass, nullptr);
    if (out == nullptr) return nullptr;
    for (jsize i = 0; i < 4; i++) {
        jstring s = env->NewStringUTF(values[i].c_str());
        env->SetObjectArrayElement(out, i, s);
        env->DeleteLocalRef(s);
    }
    return out;
} catch (...) {
    return nullptr;
}

static_assert(ms::kCategoryTampering == ms::kCatTampering, "category ordinals drifted");

const JNINativeMethod kMethods[] = {
    {"nativeVersion", "()Ljava/lang/String;", reinterpret_cast<void *>(nativeVersion)},
    {"nativeConfigure", "([IDJJZ)V", reinterpret_cast<void *>(nativeConfigure)},
    {"nativeDecide", "(ILjava/lang/String;D)I", reinterpret_cast<void *>(nativeDecide)},
    {"nativeIsBlocked", "()Z", reinterpret_cast<void *>(nativeIsBlocked)},
    {"nativeCatalog", "()[Ljava/lang/String;", reinterpret_cast<void *>(nativeCatalog)},
    {"nativeCatalogCategories", "()[I", reinterpret_cast<void *>(nativeCatalogCategories)},
    {"nativeRunChecks", "([Ljava/lang/String;)[F", reinterpret_cast<void *>(nativeRunChecks)},
    {"nativeCrossReadings", "(Ljava/lang/String;)[Ljava/lang/String;", reinterpret_cast<void *>(nativeCrossReadings)},
};

}  // namespace

extern "C" MS_EXPORT jint JNI_OnLoad(JavaVM *vm, void *) {
    JNIEnv *env = nullptr;
    if (vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) return JNI_ERR;
    jclass bridge = env->FindClass(kBridgeClass);
    if (bridge == nullptr) return JNI_ERR;
    if (env->RegisterNatives(bridge, kMethods, sizeof(kMethods) / sizeof(kMethods[0])) != JNI_OK) return JNI_ERR;
    return JNI_VERSION_1_6;
}
