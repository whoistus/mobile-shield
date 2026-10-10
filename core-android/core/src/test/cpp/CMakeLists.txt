# Host-side (macOS/Linux) tests for the native policy, watchdog and integrity logic.
#   cmake -S core-android/core/src/test/cpp -B build/native-host && cmake --build build/native-host
#   ctest --test-dir build/native-host --output-on-failure
cmake_minimum_required(VERSION 3.14)
project(mobileshield_host_tests LANGUAGES CXX)
enable_testing()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FetchContent)
set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
FetchContent_Declare(googletest
    URL https://github.com/google/googletest/archive/refs/tags/v1.15.2.tar.gz)
FetchContent_MakeAvailable(googletest)
include(GoogleTest)

set(MAIN ${CMAKE_CURRENT_SOURCE_DIR}/../../main/cpp)
find_package(Threads REQUIRED)

add_library(ms_policy STATIC ${MAIN}/policy/Policy.cpp ${MAIN}/policy/Watchdog.cpp)
target_include_directories(ms_policy PUBLIC ${MAIN})
target_compile_options(ms_policy PRIVATE -Wall -Werror)
target_link_libraries(ms_policy PUBLIC Threads::Threads)

# decision_vectors.inc comes from scripts/fixtures/gen-config-vectors.py and is committed.
foreach(name policy_test floor_test watchdog_test libintegrity_test)
    add_executable(${name} ${name}.cpp)
    target_include_directories(${name} PRIVATE ${MAIN})
    target_compile_options(${name} PRIVATE -Wall -Werror)
    target_link_libraries(${name} PRIVATE ms_policy GTest::gtest_main)
    gtest_discover_tests(${name})
endforeach()
