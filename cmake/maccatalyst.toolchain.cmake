# Mac Catalyst ARM64 CMake Toolchain File
# Builds for arm64-apple-ios15.0-macabi (Mac Catalyst)
# Usage:
#   cmake .. -DCMAKE_TOOLCHAIN_FILE=../cmake/maccatalyst.toolchain.cmake

# Use Darwin as system name since we're using the macOS SDK
# The -target flag handles the Mac Catalyst platform tagging
set(CMAKE_SYSTEM_NAME Darwin)

# Signal to the main CMakeLists.txt to skip tests/tools
set(ZVEC_CROSS_COMPILE ON CACHE BOOL "Cross-compiling for Mac Catalyst" FORCE)
set(CMAKE_SYSTEM_PROCESSOR arm64)
set(CMAKE_OSX_ARCHITECTURES arm64)

# Find the macOS SDK (Mac Catalyst uses macOS SDK, not iOS SDK)
execute_process(
    COMMAND xcrun --sdk macosx --show-sdk-path
    OUTPUT_VARIABLE CMAKE_OSX_SYSROOT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

if(NOT CMAKE_OSX_SYSROOT)
    message(FATAL_ERROR "Could not find macOS SDK. Make sure Xcode is installed.")
endif()

message(STATUS "macOS SDK (for Mac Catalyst): ${CMAKE_OSX_SYSROOT}")

# Use Apple Clang from Xcode
execute_process(
    COMMAND xcrun --sdk macosx --find clang
    OUTPUT_VARIABLE CMAKE_C_COMPILER
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
execute_process(
    COMMAND xcrun --sdk macosx --find clang++
    OUTPUT_VARIABLE CMAKE_CXX_COMPILER
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
execute_process(
    COMMAND xcrun --sdk macosx --find ar
    OUTPUT_VARIABLE CMAKE_AR
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
execute_process(
    COMMAND xcrun --sdk macosx --find ranlib
    OUTPUT_VARIABLE CMAKE_RANLIB
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Mac Catalyst target triple - use CMAKE_<LANG>_COMPILER_TARGET
# which CMake passes as --target= to the compiler
set(MACCATALYST_TARGET "arm64-apple-ios15.0-macabi")
set(CMAKE_C_COMPILER_TARGET ${MACCATALYST_TARGET})
set(CMAKE_CXX_COMPILER_TARGET ${MACCATALYST_TARGET})
set(CMAKE_ASM_COMPILER_TARGET ${MACCATALYST_TARGET})

# Don't try to run executables during configure (cross-compiling)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# Skip tests and tools for Mac Catalyst builds
set(BUILD_TOOLS OFF CACHE BOOL "Disable tools for Mac Catalyst" FORCE)
set(BUILD_PYTHON_BINDINGS OFF CACHE BOOL "Disable Python bindings for Mac Catalyst" FORCE)

# Search paths - only search in SDK, not host
set(CMAKE_FIND_ROOT_PATH ${CMAKE_OSX_SYSROOT})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

