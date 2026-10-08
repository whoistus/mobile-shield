cmake_minimum_required(VERSION 3.22.1)
project(mobileshield LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT DEFINED MS_VERSION)
    set(MS_VERSION "0.0.0-unknown")
endif()

add_library(mobileshield SHARED mobileshield.cpp)
target_compile_definitions(mobileshield PRIVATE MS_VERSION="${MS_VERSION}")
target_compile_options(mobileshield PRIVATE -fvisibility=hidden -Wall -Werror)
target_link_libraries(mobileshield PRIVATE
    -Wl,-z,max-page-size=16384
    -Wl,--build-id=sha1
    log)
