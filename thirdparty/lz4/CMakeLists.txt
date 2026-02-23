set(lz4_INCLUDE_DIR "${EXTERNAL_BINARY_DIR}/usr/local/include")
set(lz4_LIBRARY_DIR "${EXTERNAL_BINARY_DIR}/usr/local/lib/")
file(MAKE_DIRECTORY ${lz4_INCLUDE_DIR})
file(MAKE_DIRECTORY ${lz4_LIBRARY_DIR})

include(ExternalProject)

# For cross-compilation, pass the right compiler and flags to lz4's Makefile
set(LZ4_CC_ENV "CC=${CMAKE_C_COMPILER}")
set(LZ4_CFLAGS "-fPIC")
if(CMAKE_OSX_SYSROOT)
    set(LZ4_CFLAGS "${LZ4_CFLAGS} -isysroot ${CMAKE_OSX_SYSROOT}")
endif()
if(CMAKE_OSX_ARCHITECTURES)
    set(LZ4_CFLAGS "${LZ4_CFLAGS} -arch ${CMAKE_OSX_ARCHITECTURES}")
endif()
if(CMAKE_OSX_DEPLOYMENT_TARGET AND CMAKE_SYSTEM_NAME STREQUAL "iOS")
    # Detect simulator vs device vs Mac Catalyst based on SDK path
    if(CMAKE_OSX_SYSROOT MATCHES "iPhoneSimulator")
        set(LZ4_CFLAGS "${LZ4_CFLAGS} -mios-simulator-version-min=${CMAKE_OSX_DEPLOYMENT_TARGET}")
    elseif(CMAKE_C_FLAGS MATCHES "-target.*macabi")
        # Mac Catalyst: the -target flag is already in CMAKE_C_FLAGS, no extra min version needed
    else()
        set(LZ4_CFLAGS "${LZ4_CFLAGS} -mios-version-min=${CMAKE_OSX_DEPLOYMENT_TARGET}")
    endif()
endif()
# Pass through compiler target (needed for Mac Catalyst)
if(CMAKE_C_COMPILER_TARGET)
    set(LZ4_CFLAGS "${LZ4_CFLAGS} --target=${CMAKE_C_COMPILER_TARGET}")
elseif(CMAKE_C_FLAGS MATCHES "-target")
    set(LZ4_CFLAGS "${LZ4_CFLAGS} ${CMAKE_C_FLAGS}")
endif()

ExternalProject_Add(
        Lz4.BUILD
        PREFIX lz4
    URL "${CMAKE_CURRENT_SOURCE_DIR}/lz4-1.9.4"
    CONFIGURE_COMMAND ""
    BUILD_COMMAND env ${LZ4_CC_ENV} "CFLAGS=${LZ4_CFLAGS}" BUILD_SHARED=no make -j
    INSTALL_COMMAND make DESTDIR=${EXTERNAL_BINARY_DIR} BUILD_SHARED=no install
    BUILD_IN_SOURCE ON
    LOG_DOWNLOAD ON
    LOG_CONFIGURE ON
    LOG_BUILD ON
    LOG_INSTALL ON
    BUILD_BYPRODUCTS ${lz4_LIBRARY_DIR}/liblz4.a
  )

add_library(lz4 STATIC IMPORTED GLOBAL)
set_target_properties(
    lz4 PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${lz4_INCLUDE_DIR}"
    IMPORTED_LOCATION "${lz4_LIBRARY_DIR}/liblz4.a"
)
add_dependencies(lz4 Lz4.BUILD)

set(lz4_FOUND TRUE PARENT_SCOPE)
set(lz4_LIBRARY ${lz4_LIBRARY_DIR}/liblz4.a PARENT_SCOPE)
set(lz4_LIBRARIES ${lz4_LIBRARY_DIR}/liblz4.a PARENT_SCOPE)
set(lz4_INCLUDE_DIR "${EXTERNAL_BINARY_DIR}/usr/local/include" PARENT_SCOPE)
set(lz4_INCLUDE_DIRS "${EXTERNAL_BINARY_DIR}/usr/local/include" PARENT_SCOPE)
set(lz4_VERSION 1.9.4 PARENT_SCOPE)
