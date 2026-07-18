cmake_minimum_required(VERSION 3.16)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(LIBUSB_IS_TOP_LEVEL ON)
else()
    set(LIBUSB_IS_TOP_LEVEL OFF)
endif()

get_filename_component(LIBUSB_SOURCE_ROOT "libusb" ABSOLUTE)
set(LIBUSB_ROOT "${LIBUSB_SOURCE_ROOT}/libusb")

# Get the version information from version.h ignoring the nano version as it appears in version_nano.h and so we need it?
file(READ "${LIBUSB_ROOT}/version.h" VERSIONHEADERDATA)
string(REGEX MATCH "#define LIBUSB_MAJOR ([0-9]*)" _ ${VERSIONHEADERDATA})
set(LIBUSB_VERSION_MAJOR ${CMAKE_MATCH_1})
string(REGEX MATCH "#define LIBUSB_MINOR ([0-9]*)" _ ${VERSIONHEADERDATA})
set(LIBUSB_VERSION_MINOR ${CMAKE_MATCH_1})
string(REGEX MATCH "#define LIBUSB_MICRO ([0-9]*)" _ ${VERSIONHEADERDATA})
set(LIBUSB_VERSION_MICRO ${CMAKE_MATCH_1})
string(REGEX MATCH "#define LIBUSB_RC \"([^\"]*)\"" _ ${VERSIONHEADERDATA})
set(LIBUSB_VERSION_RC ${CMAKE_MATCH_1})
set(LIBUSB_VERSION "${LIBUSB_VERSION_MAJOR}.${LIBUSB_VERSION_MINOR}.${LIBUSB_VERSION_MICRO}")

project(usb-1.0
    DESCRIPTION "A cross-platform library to access USB devices"
    VERSION ${LIBUSB_VERSION}
    LANGUAGES C
)

if(CYGWIN)
    # Match upstream's Cygwin build flags for the Windows backend.
    add_compile_options(-mwin32)
endif()

if(EMSCRIPTEN)
    set(CMAKE_CXX_STANDARD 20)
    enable_language(CXX)
endif()

message(STATUS "Building usb-1.0 for: ${CMAKE_SYSTEM_NAME}")

# This function generates all the local variables what end up getting written to config.
# We use a function as any vars set in this context don't mess with the rest of the file.
# e.g. Logging LIBUSB_ENABLE_LOGGING mapps to ENABLE_LOGGING in the config, keeps it clean
function(generate_config_file)
    include(CheckIncludeFiles)
    include(CheckFunctionExists)
    include(CheckSymbolExists)
    include(CheckStructHasMember)
    include(CheckCCompilerFlag)

    # The Windows backend needs a fallback when clock_gettime is unavailable.
    # POSIX backends use it too, except on Apple platforms.
    if(NOT APPLE)
        check_function_exists(clock_gettime HAVE_CLOCK_GETTIME)
    endif()

    # The Windows backend needs to know whether it must provide struct timespec.
    if(WIN32 OR CYGWIN)
        check_struct_has_member("struct timespec" tv_sec time.h HAVE_STRUCT_TIMESPEC)
    endif()

    # Cygwin uses the Windows backend but still needs <sys/time.h>.
    if(NOT WIN32 OR CYGWIN)
        check_include_files(sys/time.h HAVE_SYS_TIME_H)
    endif()

    # Android logging does not reach the syslog path in core.c.
    if((NOT WIN32 OR CYGWIN) AND NOT ANDROID)
        check_function_exists(syslog HAVE_SYSLOG)
    endif()

    # These checks control paths compiled only by the POSIX backend.
    if(NOT (WIN32 OR CYGWIN))
        check_function_exists(pthread_condattr_setclock HAVE_PTHREAD_CONDATTR_SETCLOCK)
        check_function_exists(eventfd                   HAVE_EVENTFD)
        check_function_exists(pipe2                     HAVE_PIPE2)

        check_symbol_exists(timerfd_create "sys/timerfd.h" HAVE_TIMERFD)
        check_symbol_exists(nfds_t        "poll.h"       HAVE_NFDS_T)

        if(CMAKE_SYSTEM_NAME MATCHES "Linux" OR ANDROID)
            check_include_files(asm/types.h      HAVE_ASM_TYPES_H)
            check_function_exists(pthread_setname_np HAVE_PTHREAD_SETNAME_NP)
        endif()

        if(APPLE)
            check_function_exists(pthread_threadid_np HAVE_PTHREAD_THREADID_NP)
        endif()
    endif()

    if(CMAKE_C_COMPILER_ID MATCHES "Clang" OR CMAKE_C_COMPILER_ID STREQUAL "GNU")
        check_c_compiler_flag("-fvisibility=hidden" HAVE_VISIBILITY)
    else()
        set(HAVE_VISIBILITY OFF)
    endif()

    if(HAVE_VISIBILITY)
        set(DEFAULT_VISIBILITY "__attribute__((visibility(\"default\")))")
    else()
        set(DEFAULT_VISIBILITY "" )
    endif()

    # Set vars that will be written into the config file.
    if(WIN32 OR CYGWIN)
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

    if((WIN32 OR CYGWIN) AND LIBUSB_ENABLE_WINDOWS_HOTPLUG)
        set(LIBUSB_WINDOWS_HOTPLUG 1)
    endif()

    file(MAKE_DIRECTORY "${LIBUSB_GEN_INCLUDES}")
    if(NOT MSVC)
        set(_GNU_SOURCE TRUE)
    endif()
    configure_file(config.h.in "${LIBUSB_GEN_INCLUDES}/config.h" @ONLY)
endfunction()

if(BUILD_SHARED_LIBS)
    set(LIBUSB_BUILD_SHARED_LIBS_DEFAULT ON)
else()
    set(LIBUSB_BUILD_SHARED_LIBS_DEFAULT OFF)
endif()

include(CMakeDependentOption)

option(LIBUSB_BUILD_SHARED_LIBS "Build Shared Libraries for libusb" ${LIBUSB_BUILD_SHARED_LIBS_DEFAULT})
option(LIBUSB_BUILD_TESTING "Build Tests" OFF)
if(LIBUSB_BUILD_TESTING)
    enable_testing()
endif()

option(LIBUSB_BUILD_EXAMPLES "Build Example Applications" OFF)

option(LIBUSB_INSTALL_TARGETS "Install libusb targets" ON)
cmake_dependent_option(LIBUSB_EXPORT_INSTALL_TARGETS "Install CMake package files" ON LIBUSB_INSTALL_TARGETS OFF)
cmake_dependent_option(LIBUSB_INSTALL_PKGCONFIG "Install pkg-config metadata" ON LIBUSB_INSTALL_TARGETS OFF)

option(LIBUSB_TARGETS_INCLUDE_USING_SYSTEM "Make targets include paths System" ON)

option(LIBUSB_ENABLE_LOGGING "Enable Logging" ON)
option(LIBUSB_ENABLE_DEBUG_LOGGING "Enable Debug Logging" OFF)
if(CMAKE_SYSTEM_NAME MATCHES "Linux")
    option(LIBUSB_ENABLE_UDEV "Enable udev backend for device enumeration" ON)
endif()

if(WIN32 OR CYGWIN)
    option(LIBUSB_ENABLE_WINDOWS_HOTPLUG "Enable Windows hotplug support" OFF)
endif()

#

if(LIBUSB_INSTALL_TARGETS)
    # to make sure all variables, like CMAKE_INSTALL_LIBDIR, are initialized
    include(GNUInstallDirs)
endif()

function(libusb_configure_pc)
    set(VERSION "${LIBUSB_VERSION}${LIBUSB_VERSION_RC}")
    set(prefix "${CMAKE_INSTALL_PREFIX}")
    set(exec_prefix "\${prefix}")

    if(IS_ABSOLUTE "${CMAKE_INSTALL_LIBDIR}")
        set(libdir "${CMAKE_INSTALL_LIBDIR}")
    else()
        set(libdir "\${exec_prefix}/${CMAKE_INSTALL_LIBDIR}")
    endif()

    if(IS_ABSOLUTE "${CMAKE_INSTALL_INCLUDEDIR}")
        set(includedir "${CMAKE_INSTALL_INCLUDEDIR}")
    else()
        set(includedir "\${prefix}/${CMAKE_INSTALL_INCLUDEDIR}")
    endif()

    string(JOIN " " LIBS ${LIBUSB_PC_LIBS_PRIVATE})
    configure_file(
        "${LIBUSB_SOURCE_ROOT}/libusb-1.0.pc.in"
        "${CMAKE_CURRENT_BINARY_DIR}/libusb-1.0.pc"
        @ONLY
    )
endfunction()

set(LIBUSB_GEN_INCLUDES "${CMAKE_CURRENT_BINARY_DIR}/gen_include")
generate_config_file()

set(LIBUSB_VERSION_DESCRIBE_ROOT "${CMAKE_CURRENT_BINARY_DIR}/libusb-version-describe")
set(LIBUSB_VERSION_DESCRIBE_HEADER "${LIBUSB_GEN_INCLUDES}/version_describe.h")
set(LIBUSB_VERSION_DESCRIBE_LOCK "${CMAKE_CURRENT_SOURCE_DIR}/.libusb-upstream.describe")
set(LIBUSB_VERSION_DESCRIBE_SCRIPT "${LIBUSB_SOURCE_ROOT}/build-aux/gen-describe.sh")
set(LIBUSB_VERSION_DESCRIBE_DEPENDS)

if(CMAKE_HOST_WIN32)
    find_program(LIBUSB_POWERSHELL_EXECUTABLE NAMES powershell pwsh)
    if(NOT LIBUSB_POWERSHELL_EXECUTABLE)
        message(FATAL_ERROR "PowerShell is required to generate version_describe.h")
    endif()
    set(LIBUSB_VERSION_DESCRIBE_COMMAND
        "${LIBUSB_POWERSHELL_EXECUTABLE}"
        -NoProfile
        -ExecutionPolicy Bypass
        -File "${LIBUSB_SOURCE_ROOT}/build-aux/gen-describe.ps1"
    )
    set(LIBUSB_VERSION_DESCRIBE_DEPENDS
        "${LIBUSB_SOURCE_ROOT}/build-aux/gen-describe.ps1"
    )
else()
    find_program(LIBUSB_SH_EXECUTABLE NAMES sh)
    if(NOT LIBUSB_SH_EXECUTABLE)
        message(FATAL_ERROR "A POSIX shell is required to generate version_describe.h")
    endif()
    set(LIBUSB_VERSION_DESCRIBE_COMMAND
        "${LIBUSB_SH_EXECUTABLE}"
        "${LIBUSB_VERSION_DESCRIBE_SCRIPT}"
    )
endif()

add_custom_command(
    OUTPUT "${LIBUSB_VERSION_DESCRIBE_HEADER}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${LIBUSB_VERSION_DESCRIBE_ROOT}"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${LIBUSB_VERSION_DESCRIBE_LOCK}"
        "${LIBUSB_VERSION_DESCRIBE_ROOT}/.tarball-version"
    COMMAND ${LIBUSB_VERSION_DESCRIBE_COMMAND}
        "${LIBUSB_VERSION_DESCRIBE_ROOT}"
        "${LIBUSB_VERSION_DESCRIBE_HEADER}"
    DEPENDS
        "${LIBUSB_VERSION_DESCRIBE_LOCK}"
        "${LIBUSB_VERSION_DESCRIBE_SCRIPT}"
        ${LIBUSB_VERSION_DESCRIBE_DEPENDS}
    COMMENT "Generating version_describe.h"
    VERBATIM
)

#
#
#

if(LIBUSB_BUILD_SHARED_LIBS)
    add_library(usb-1.0 SHARED)
else()
    add_library(usb-1.0 STATIC)
endif()

add_library(libusb::usb-1.0 ALIAS usb-1.0)

set_target_properties(usb-1.0 PROPERTIES
    EXPORT_NAME usb-1.0
    PREFIX lib # to be consistent with mainline libusb build system(s)
)

# common sources
target_sources(usb-1.0 PRIVATE
    "${LIBUSB_GEN_INCLUDES}/config.h"
    "${LIBUSB_VERSION_DESCRIBE_HEADER}"
    "${LIBUSB_ROOT}/core.c"
    "${LIBUSB_ROOT}/descriptor.c"
    "${LIBUSB_ROOT}/hotplug.c"
    "${LIBUSB_ROOT}/io.c"
    "${LIBUSB_ROOT}/libusb.h"
    "${LIBUSB_ROOT}/libusbi.h"
    "${LIBUSB_ROOT}/strerror.c"
    "${LIBUSB_ROOT}/sync.c"
    "${LIBUSB_ROOT}/version.h"
    "${LIBUSB_ROOT}/version_nano.h"
)
target_include_directories(usb-1.0
    PRIVATE
        "${LIBUSB_GEN_INCLUDES}"
        "${LIBUSB_ROOT}/os"
)

if(LIBUSB_TARGETS_INCLUDE_USING_SYSTEM)
    set(LIBUSB_SYSTEM_FLAGS SYSTEM)
else()
    set(LIBUSB_SYSTEM_FLAGS)
endif()

add_library(libusb_include INTERFACE)
add_library(libusb::include ALIAS libusb_include)
set_target_properties(libusb_include PROPERTIES EXPORT_NAME include)
target_include_directories(libusb_include
    ${LIBUSB_SYSTEM_FLAGS} INTERFACE
    $<BUILD_INTERFACE:${LIBUSB_ROOT}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/libusb-1.0>
)
target_link_libraries(usb-1.0 PUBLIC libusb_include)

set(LIBUSB_PRIVATE_LINK_LIBRARIES)
# Append matching pkg-config flags beside each private CMake link item below.
set(LIBUSB_PC_LIBS_PRIVATE)
set(LIBUSB_CONFIG_NEEDS_THREADS OFF)

if(WIN32 OR CYGWIN)
    target_sources(usb-1.0 PRIVATE
        "${LIBUSB_ROOT}/libusb-1.0.def"
        "${LIBUSB_ROOT}/os/events_windows.c"
        "${LIBUSB_ROOT}/os/events_windows.h"
        "${LIBUSB_ROOT}/os/threads_windows.c"
        "${LIBUSB_ROOT}/os/threads_windows.h"
        "${LIBUSB_ROOT}/os/windows_common.c"
        "${LIBUSB_ROOT}/os/windows_common.h"
        "${LIBUSB_ROOT}/os/windows_usbdk.c"
        "${LIBUSB_ROOT}/os/windows_usbdk.h"
        "${LIBUSB_ROOT}/os/windows_winusb.c"
        "${LIBUSB_ROOT}/os/windows_winusb.h"
        $<$<C_COMPILER_ID:MSVC>:${LIBUSB_ROOT}/libusb-1.0.rc>
    )
    target_compile_definitions(usb-1.0 PRIVATE $<$<C_COMPILER_ID:MSVC>:_CRT_SECURE_NO_WARNINGS=1>)

    if(CMAKE_SYSTEM_NAME STREQUAL "WindowsStore")
        # UWP/Store builds require the WindowsApp umbrella library
        list(APPEND LIBUSB_PRIVATE_LINK_LIBRARIES windowsapp)
        list(APPEND LIBUSB_PC_LIBS_PRIVATE -lwindowsapp)
    else()
        # windowsapp pulls in API-set imports unavailable on Windows 7
        list(APPEND LIBUSB_PRIVATE_LINK_LIBRARIES kernel32 user32)
        list(APPEND LIBUSB_PC_LIBS_PRIVATE -lkernel32 -luser32)
    endif()

    if(LIBUSB_ENABLE_WINDOWS_HOTPLUG)
        target_sources(usb-1.0 PRIVATE
            "${LIBUSB_ROOT}/os/windows_hotplug.c"
            "${LIBUSB_ROOT}/os/windows_hotplug.h"
        )
        target_compile_definitions(usb-1.0 PRIVATE LIBUSB_WINDOWS_HOTPLUG=1)
    endif()
    set_target_properties(usb-1.0 PROPERTIES UNITY_BUILD OFF)
else()
    # common POSIX/non-Windows sources
    target_sources(usb-1.0 PRIVATE
        "${LIBUSB_ROOT}/os/events_posix.c"
        "${LIBUSB_ROOT}/os/events_posix.h"
        "${LIBUSB_ROOT}/os/threads_posix.c"
        "${LIBUSB_ROOT}/os/threads_posix.h"
    )
    if(CMAKE_SYSTEM_NAME MATCHES "Linux")
        target_sources(usb-1.0 PRIVATE
            "${LIBUSB_ROOT}/os/linux_usbfs.c"
            "${LIBUSB_ROOT}/os/linux_usbfs.h"
        )
        if(LIBUSB_ENABLE_UDEV)
            target_sources(usb-1.0 PRIVATE
                "${LIBUSB_ROOT}/os/linux_udev.c"
            )
            list(APPEND LIBUSB_PRIVATE_LINK_LIBRARIES udev)
            list(APPEND LIBUSB_PC_LIBS_PRIVATE -ludev)
            target_compile_definitions(usb-1.0 PRIVATE HAVE_LIBUDEV=1)
        else()
            target_sources(usb-1.0 PRIVATE
                "${LIBUSB_ROOT}/os/linux_netlink.c"
            )
        endif()
        find_package(Threads REQUIRED)
        list(APPEND LIBUSB_PRIVATE_LINK_LIBRARIES Threads::Threads)
        if(CMAKE_THREAD_LIBS_INIT)
            list(APPEND LIBUSB_PC_LIBS_PRIVATE "${CMAKE_THREAD_LIBS_INIT}")
        endif()
        if(NOT LIBUSB_BUILD_SHARED_LIBS)
            set(LIBUSB_CONFIG_NEEDS_THREADS ON)
        endif()
    elseif(ANDROID)
        target_sources(usb-1.0 PRIVATE
            "${LIBUSB_ROOT}/os/linux_netlink.c"
            "${LIBUSB_ROOT}/os/linux_usbfs.c"
            "${LIBUSB_ROOT}/os/linux_usbfs.h"
        )
        list(APPEND LIBUSB_PRIVATE_LINK_LIBRARIES android log)
        list(APPEND LIBUSB_PC_LIBS_PRIVATE -landroid -llog)
    elseif(APPLE)
        target_sources(usb-1.0 PRIVATE
            "${LIBUSB_ROOT}/os/darwin_usb.c"
            "${LIBUSB_ROOT}/os/darwin_usb.h"
        )
        list(APPEND LIBUSB_PRIVATE_LINK_LIBRARIES
            "-framework Foundation"
            "-framework IOKit"
            "-framework Security"
        )
        list(APPEND LIBUSB_PC_LIBS_PRIVATE
            "-framework Foundation"
            "-framework IOKit"
            "-framework Security"
        )
    elseif(CMAKE_SYSTEM_NAME STREQUAL "NetBSD")
        target_sources(usb-1.0 PRIVATE
            "${LIBUSB_ROOT}/os/netbsd_usb.c"
        )
    elseif(CMAKE_SYSTEM_NAME STREQUAL "OpenBSD")
        target_sources(usb-1.0 PRIVATE
            "${LIBUSB_ROOT}/os/openbsd_usb.c"
        )
    elseif(CMAKE_SYSTEM_NAME STREQUAL "SunOS")
        target_sources(usb-1.0 PRIVATE
            "${LIBUSB_ROOT}/os/sunos_usb.c"
        )
        list(APPEND LIBUSB_PRIVATE_LINK_LIBRARIES -ldevinfo -lnvpair)
        list(APPEND LIBUSB_PC_LIBS_PRIVATE -ldevinfo -lnvpair)
    elseif(EMSCRIPTEN)
        target_sources(usb-1.0 PRIVATE
            "${LIBUSB_ROOT}/os/emscripten_webusb.cpp"
        )
        target_compile_options(usb-1.0 PRIVATE -pthread)
        # Embind and Asyncify must reach the final executable.
        target_link_libraries(usb-1.0 PUBLIC -lembind)
        target_link_options(usb-1.0 PUBLIC
            -pthread
            -sASYNCIFY
        )
        list(APPEND LIBUSB_PC_LIBS_PRIVATE -pthread -lembind -sASYNCIFY)
    else()
        message(FATAL_ERROR "Unsupported target platform: ${CMAKE_SYSTEM_NAME}")
    endif()
endif()

if(LIBUSB_PRIVATE_LINK_LIBRARIES)
    target_link_libraries(usb-1.0 PRIVATE ${LIBUSB_PRIVATE_LINK_LIBRARIES})
endif()

if(LIBUSB_BUILD_TESTING)
    add_subdirectory(tests)
endif()

if(LIBUSB_BUILD_EXAMPLES)
    add_subdirectory(examples)
endif()

if(LIBUSB_INSTALL_TARGETS)
    install(FILES "${LIBUSB_ROOT}/libusb.h" DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/libusb-1.0")

    install(TARGETS usb-1.0 libusb_include
        EXPORT libusb-targets
    )

    if(LIBUSB_INSTALL_PKGCONFIG)
        libusb_configure_pc()
        install(FILES "${CMAKE_CURRENT_BINARY_DIR}/libusb-1.0.pc"
            DESTINATION "${CMAKE_INSTALL_LIBDIR}/pkgconfig"
        )
    endif()

    if(LIBUSB_EXPORT_INSTALL_TARGETS)
        set(LIBUSB_INSTALL_CMAKEDIR "${CMAKE_INSTALL_LIBDIR}/cmake/libusb")

        install(EXPORT libusb-targets
            FILE libusb-targets.cmake
            NAMESPACE libusb::
            DESTINATION "${LIBUSB_INSTALL_CMAKEDIR}"
        )

        include(CMakePackageConfigHelpers)

        configure_package_config_file(
            "${CMAKE_CURRENT_SOURCE_DIR}/cmake/libusb-config.cmake.in"
            "${CMAKE_CURRENT_BINARY_DIR}/libusb-config.cmake"
            INSTALL_DESTINATION "${LIBUSB_INSTALL_CMAKEDIR}"
            NO_SET_AND_CHECK_MACRO
        )

        write_basic_package_version_file(
            "${CMAKE_CURRENT_BINARY_DIR}/libusb-config-version.cmake"
            VERSION ${LIBUSB_VERSION}
            COMPATIBILITY SameMajorVersion
        )

        install(FILES
            "${CMAKE_CURRENT_BINARY_DIR}/libusb-config.cmake"
            "${CMAKE_CURRENT_BINARY_DIR}/libusb-config-version.cmake"
            "${CMAKE_CURRENT_SOURCE_DIR}/cmake/usb-1.0-targets.cmake"
            DESTINATION "${LIBUSB_INSTALL_CMAKEDIR}"
        )
    endif()
endif()
