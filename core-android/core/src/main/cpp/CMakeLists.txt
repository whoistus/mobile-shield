cmake_minimum_required(VERSION 3.22.1)
project(mobileshield LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT DEFINED MS_VERSION)
    set(MS_VERSION "0.0.0-unknown")
endif()

add_library(mobileshield SHARED
    mobileshield.cpp
    policy/Policy.cpp
    policy/Watchdog.cpp
    detectors/Registry.cpp
    detectors/RootDetect.cpp
    detectors/AntiDebug.cpp
    detectors/AntiDump.cpp
    detectors/FridaDetect.cpp
    detectors/LibIntegrity.cpp
    detectors/CrossReadings.cpp)

target_compile_definitions(mobileshield PRIVATE MS_VERSION="${MS_VERSION}")
# Logging exists only in debug builds: release has no log strings and no android/log calls.
if(MSHIELD_DEBUG)
    target_compile_definitions(mobileshield PRIVATE MSHIELD_DEBUG=1)
    target_link_libraries(mobileshield PRIVATE log)
endif()

target_compile_options(mobileshield PRIVATE
    -fvisibility=hidden -fvisibility-inlines-hidden
    -ffunction-sections -fdata-sections
    -fstack-protector-strong -fno-rtti
    -Wall -Werror)
# JNI_OnLoad is the only exported symbol; --exclude-libs keeps libc++_static's symbols hidden too.
target_link_libraries(mobileshield PRIVATE
    -Wl,-z,max-page-size=16384
    -Wl,--build-id=sha1
    -Wl,--gc-sections
    -Wl,--exclude-libs,ALL)
