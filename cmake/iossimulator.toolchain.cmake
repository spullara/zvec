# iOS Simulator ARM64 CMake Toolchain File
# Usage:
#   cmake .. -DCMAKE_TOOLCHAIN_FILE=../cmake/iossimulator.toolchain.cmake

set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_SYSTEM_PROCESSOR arm64)
set(CMAKE_OSX_ARCHITECTURES arm64)

# Find the iOS Simulator SDK
execute_process(
    COMMAND xcrun --sdk iphonesimulator --show-sdk-path
    OUTPUT_VARIABLE CMAKE_OSX_SYSROOT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

if(NOT CMAKE_OSX_SYSROOT)
    message(FATAL_ERROR "Could not find iPhoneSimulator SDK. Make sure Xcode is installed.")
endif()

message(STATUS "iOS Simulator SDK: ${CMAKE_OSX_SYSROOT}")

# Minimum iOS deployment target
set(CMAKE_OSX_DEPLOYMENT_TARGET "15.0" CACHE STRING "Minimum iOS deployment target")

# Use Apple Clang from Xcode (simulator SDK)
execute_process(
    COMMAND xcrun --sdk iphonesimulator --find clang
    OUTPUT_VARIABLE CMAKE_C_COMPILER
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
execute_process(
    COMMAND xcrun --sdk iphonesimulator --find clang++
    OUTPUT_VARIABLE CMAKE_CXX_COMPILER
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
execute_process(
    COMMAND xcrun --sdk iphonesimulator --find ar
    OUTPUT_VARIABLE CMAKE_AR
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
execute_process(
    COMMAND xcrun --sdk iphonesimulator --find ranlib
    OUTPUT_VARIABLE CMAKE_RANLIB
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Don't try to run executables during configure (cross-compiling)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# Skip tests and tools for iOS Simulator builds
set(BUILD_TOOLS OFF CACHE BOOL "Disable tools for iOS Simulator" FORCE)
set(BUILD_PYTHON_BINDINGS OFF CACHE BOOL "Disable Python bindings for iOS Simulator" FORCE)

# Search paths - only search in SDK, not host
set(CMAKE_FIND_ROOT_PATH ${CMAKE_OSX_SYSROOT})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

