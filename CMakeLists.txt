cmake_minimum_required(VERSION 3.16)

# define the source root
set(LIBUSB_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/libusb/libusb")

# Get the version information from version.h ignoring the nano version as it appears in version_nano.h and so we need it?
file(READ "${LIBUSB_ROOT}/version.h" VERSIONHEADERDATA)
string(REGEX MATCH "#define LIBUSB_MAJOR ([0-9]*)" _ ${VERSIONHEADERDATA} )
set(LIBUSB_VERSION_MAJOR ${CMAKE_MATCH_1})
string(REGEX MATCH "#define LIBUSB_MINOR ([0-9]*)" _ ${VERSIONHEADERDATA} )
set(LIBUSB_VERSION_MINOR ${CMAKE_MATCH_1})
string(REGEX MATCH "#define LIBUSB_MICRO ([0-9]*)" _ ${VERSIONHEADERDATA} )
set(LIBUSB_VERSION_MICRO ${CMAKE_MATCH_1})
set(LIBUSB_VERSION "${LIBUSB_VERSION_MAJOR}.${LIBUSB_VERSION_MINOR}.${LIBUSB_VERSION_MICRO}")

project(usb-1.0
  DESCRIPTION "A cross-platform library to access USB devices"
  VERSION ${LIBUSB_VERSION}
  LANGUAGES C )

if(MINGW)
  # This is because CMake on mingw can incorrectly use response files for includes
  # instead of passing them directly via -I<dir>
  # Explicitly disable use of response files
  set(CMAKE_C_USE_RESPONSE_FILE_FOR_INCLUDES OFF)
endif()

# This function generates all the local variables what end up getting written to config.
# We use a function as any vars set in this context don't mess with the rest of the file.
# e.g. Logging LIBUSB_ENABLE_LOGGING mapps to ENABLE_LOGGING in the config, keeps it clean
function(GenerateConfigFile)
    include(CheckIncludeFiles)
    include(CheckFunctionExists)
    include(CheckSymbolExists)
    include(CheckStructHasMember)
    include(CheckCCompilerFlag)

    check_function_exists(clock_gettime             HAVE_CLOCK_GETTIME)
    check_function_exists(pthread_condattr_setclock HAVE_PTHREAD_CONDATTR_SETCLOCK)
    check_function_exists(pthread_setname_np        HAVE_PTHREAD_SETNAME_NP)
    check_function_exists(pthread_threadid_np       HAVE_PTHREAD_THREADID_NP)
    check_function_exists(eventfd                   HAVE_EVENTFD)
    check_function_exists(pipe2                     HAVE_PIPE2)
    check_function_exists(syslog                    HAVE_SYSLOG)

    check_include_files(asm/types.h      HAVE_ASM_TYPES_H)
    check_include_files(sys/eventfd.h    HAVE_EVENTFD)
    check_include_files(string.h         HAVE_STRING_H)
    check_include_files(sys/time.h       HAVE_SYS_TIME_H)

    check_symbol_exists(timerfd_create  "sys/timerfd.h" HAVE_TIMERFD)
    check_symbol_exists(nfds_t  "poll.h" HAVE_NFDS_T)

    check_struct_has_member("struct timespec" tv_sec time.h HAVE_STRUCT_TIMESPEC)

    if(HAVE_VISIBILITY)
        set(DEFAULT_VISIBILITY "__attribute__((visibility(\"default\")))")
    else()
        set(DEFAULT_VISIBILITY "" )
    endif()

    # Set vars that will be written into the config file.
    if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
        set(PLATFORM_WINDOWS 1)
    else()
        set(PLATFORM_POSIX 1)
    endif()

    if(LIBUSB_ENABLE_LOGGING)
        set(ENABLE_LOGGING ${LIBUSB_ENABLE_LOGGING})
    endif()
    if(LIBUSB_ENABLE_DEBUG_LOGGING)
        set(ENABLE_DEBUG_LOGGING ${LIBUSB_ENABLE_DEBUG_LOGGING})
    endif()

    if(CMAKE_C_COMPILER_ID STREQUAL "Clang" OR CMAKE_C_COMPILER_ID STREQUAL "GNU")
        check_c_compiler_flag("-fvisibility=hidden" HAVE_VISIBILITY)
    endif()

    file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/gen_include")
    configure_file(config.h.in "${CMAKE_CURRENT_BINARY_DIR}/gen_include/config.h" @ONLY)
endfunction()

if(BUILD_SHARED_LIBS)
    set(LIBUSB_BUILD_SHARED_LIBS_DEFAULT ON)
else (BUILD_SHARED_LIBS)
    set(LIBUSB_BUILD_SHARED_LIBS_DEFAULT OFF)
endif (BUILD_SHARED_LIBS)

option(LIBUSB_BUILD_SHARED_LIBS "Build Shared Libraries for libusb" ${LIBUSB_BUILD_SHARED_LIBS_DEFAULT})
option(LIBUSB_BUILD_TESTING "Build Tests" ON)
option(LIBUSB_BUILD_EXAMPLES "Build Example Applications" ON)

option(LIBUSB_INSTALL_TARGETS "Install libusb targets" ON)
option(LIBUSB_TARGETS_INCLUDE_USING_SYSTEM "Make targets include paths System" ON)

option(LIBUSB_ENABLE_LOGGING "Enable Logging" ON)
option(LIBUSB_ENABLE_DEBUG_LOGGING "Enable Debug Logging" OFF)

GenerateConfigFile()

if(LIBUSB_BUILD_SHARED_LIBS)
    add_library(usb-1.0 SHARED)
else()
    add_library(usb-1.0 STATIC)
endif()

# Handle all the common sources and compiler stuff
target_sources(usb-1.0 PRIVATE
    ${LIBUSB_ROOT}/core.c
    ${LIBUSB_ROOT}/descriptor.c
    ${LIBUSB_ROOT}/hotplug.c
    ${LIBUSB_ROOT}/io.c
    ${LIBUSB_ROOT}/sync.c
    ${LIBUSB_ROOT}/strerror.c
    ${LIBUSB_ROOT}/libusb.h
    ${LIBUSB_ROOT}/libusbi.h
    ${LIBUSB_ROOT}/version_nano.h
    ${LIBUSB_ROOT}/version.h
    ${CMAKE_CURRENT_BINARY_DIR}/gen_include/config.h
)
target_include_directories(usb-1.0
    PUBLIC
        ${LIBUSB_ROOT}
    PRIVATE
        ${CMAKE_CURRENT_BINARY_DIR}/gen_include
        ${LIBUSB_ROOT}/os
)

if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    target_sources(usb-1.0 PRIVATE
        ${LIBUSB_ROOT}/os/windows_common.c
        ${LIBUSB_ROOT}/os/windows_usbdk.c
        ${LIBUSB_ROOT}/os/windows_winusb.c
        ${LIBUSB_ROOT}/os/events_windows.c
        ${LIBUSB_ROOT}/os/threads_windows.c
        ${LIBUSB_ROOT}/os/events_windows.h
        ${LIBUSB_ROOT}/os/threads_windows.h
        ${LIBUSB_ROOT}/os/windows_common.h
        ${LIBUSB_ROOT}/os/windows_usbdk.h
        ${LIBUSB_ROOT}/os/windows_winusb.h
        ${LIBUSB_ROOT}/libusb-1.0.def
        $<$<C_COMPILER_ID:MSVC>:${LIBUSB_ROOT}/libusb-1.0.rc>
    )
    target_compile_definitions(usb-1.0 PRIVATE $<$<C_COMPILER_ID:MSVC>:_CRT_SECURE_NO_WARNINGS=1>)
    target_link_libraries(usb-1.0 PRIVATE windowsapp)
else()
    # If it's not Windows then it's a POSIX system
    target_sources(usb-1.0 PRIVATE
        ${LIBUSB_ROOT}/os/events_posix.c
        ${LIBUSB_ROOT}/os/threads_posix.c
        ${LIBUSB_ROOT}/os/events_posix.h
        ${LIBUSB_ROOT}/os/threads_posix.h
    )
    # For the Linux based OSs - This should work
    if(CMAKE_SYSTEM_NAME STREQUAL "Linux" OR CMAKE_SYSTEM_NAME STREQUAL "Android")
        target_sources(usb-1.0 PRIVATE
            ${LIBUSB_ROOT}/os/linux_usbfs.c
            ${LIBUSB_ROOT}/os/linux_usbfs.h
        )
        if(CMAKE_SYSTEM_NAME STREQUAL "Android")
            target_sources(usb-1.0 PRIVATE
                ${LIBUSB_ROOT}/os/linux_netlink.c
            )
            target_link_libraries(usb-1.0 PRIVATE android log)
        else()
            # Normal Linux
            target_sources(usb-1.0 PRIVATE
                ${LIBUSB_ROOT}/os/linux_udev.c
            )
            target_link_libraries(usb-1.0 PRIVATE udev pthread)
            target_compile_definitions(usb-1.0 PRIVATE HAVE_LIBUDEV=1)
        endif()
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
        # Or MacOS/iOS etc etc to anyone who does not know
        target_sources(usb-1.0 PRIVATE
            ${LIBUSB_ROOT}/os/darwin_usb.c
            ${LIBUSB_ROOT}/os/darwin_usb.h
        )
        target_link_libraries(usb-1.0 PRIVATE
            "-framework Foundation"
            "-framework IOKit"
            "-framework Security"
        )
    elseif(CMAKE_SYSTEM_NAME STREQUAL "NetBSD")
        target_sources(usb-1.0 PRIVATE
            ${LIBUSB_ROOT}/os/netbsd_usb.c
        )
    elseif(CMAKE_SYSTEM_NAME STREQUAL "OpenBSD")
        target_sources(usb-1.0 PRIVATE
            ${LIBUSB_ROOT}/os/openbsd_usb.c
        )
    else()
        message(FATAL_ERROR "Unsupported target platform: ${CMAKE_SYSTEM_NAME}")
    endif()
endif()

if(LIBUSB_BUILD_TESTING)
    add_executable(testlib ${LIBUSB_ROOT}/../tests/testlib.c ${LIBUSB_ROOT}/../tests/stress.c)
    target_link_libraries(testlib PRIVATE usb-1.0)
    target_include_directories(testlib PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/gen_include )
    add_test(testlib COMMAND testlib)
endif()

if(LIBUSB_BUILD_EXAMPLES)

    if(CMAKE_C_COMPILER_ID STREQUAL "MSVC")
        add_library(getoptMSVC STATIC
            ${LIBUSB_ROOT}/../msvc/getopt/getopt.h
            ${LIBUSB_ROOT}/../msvc/getopt/getopt.c
            ${LIBUSB_ROOT}/../msvc/getopt/getopt1.c
        )
        # Need to pass HAVE_CONFIG_H so getopt.h can load the config header
        target_compile_definitions(getoptMSVC PRIVATE HAVE_CONFIG_H)
        target_include_directories(getoptMSVC
            PUBLIC "${LIBUSB_ROOT}/../msvc/getopt/"
            PUBLIC "C:/temp/"
            PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/gen_include
        )
    endif()

    add_executable(listdevs ${LIBUSB_ROOT}/../examples/listdevs.c)
    target_include_directories(listdevs PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/gen_include)
    target_link_libraries(listdevs PRIVATE usb-1.0)

    add_executable(dpfp ${LIBUSB_ROOT}/../examples/dpfp.c)
    target_include_directories(dpfp PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/gen_include)
    target_link_libraries(dpfp PRIVATE usb-1.0)

    add_executable(hotplugtest ${LIBUSB_ROOT}/../examples/hotplugtest.c)
    target_include_directories(hotplugtest PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/gen_include)
    target_link_libraries(hotplugtest PRIVATE usb-1.0)

    add_executable(fxload ${LIBUSB_ROOT}/../examples/fxload.c ${LIBUSB_ROOT}/../examples/ezusb.c ${LIBUSB_ROOT}/../examples/ezusb.h)
    target_include_directories(fxload PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/gen_include )
    target_link_libraries(fxload PRIVATE usb-1.0 $<$<C_COMPILER_ID:MSVC>:getoptMSVC> )

    add_executable(testlibusb ${LIBUSB_ROOT}/../examples/testlibusb.c)
    target_include_directories(testlibusb PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/gen_include )
    target_link_libraries(testlibusb PRIVATE usb-1.0)

    add_executable(sam3u_benchmark ${LIBUSB_ROOT}/../examples/sam3u_benchmark.c)
    target_include_directories(sam3u_benchmark PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/gen_include )
    target_link_libraries(sam3u_benchmark PRIVATE usb-1.0)

    add_executable(xusb ${LIBUSB_ROOT}/../examples/xusb.c)
    target_include_directories(xusb PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/gen_include )
    target_link_libraries(xusb PRIVATE usb-1.0)
endif()

if(LIBUSB_INSTALL_TARGETS)
    install(TARGETS usb-1.0)
    install(FILES ${LIBUSB_ROOT}/libusb.h DESTINATION include/libusb-1.0)
endif()
