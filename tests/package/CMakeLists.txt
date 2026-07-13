cmake_minimum_required(VERSION 3.16)

project(libusb_package_consumer LANGUAGES C)

if(EMSCRIPTEN)
    enable_language(CXX)
endif()

if(LIBUSB_USE_LEGACY_TARGETS)
    if(NOT LIBUSB_LEGACY_PACKAGE_DIR)
        message(FATAL_ERROR "LIBUSB_LEGACY_PACKAGE_DIR is required")
    endif()
    # This filename was the only export installed by libusb-cmake 1.0.30.
    include("${LIBUSB_LEGACY_PACKAGE_DIR}/usb-1.0-targets.cmake")
elseif(LIBUSB_REQUIRED_VERSION)
    find_package(libusb ${LIBUSB_REQUIRED_VERSION} CONFIG REQUIRED)
else()
    find_package(libusb CONFIG REQUIRED)
endif()

foreach(_target libusb::usb-1.0 libusb::include)
    if(NOT TARGET ${_target})
        message(FATAL_ERROR "Required target ${_target} is missing")
    endif()
endforeach()

add_library(libusb_include_consumer OBJECT include.c)
target_link_libraries(libusb_include_consumer PRIVATE libusb::include)

add_executable(libusb_package_consumer main.c)
target_link_libraries(libusb_package_consumer PRIVATE libusb::usb-1.0)

if(WIN32 OR CYGWIN)
    get_target_property(_libusb_type libusb::usb-1.0 TYPE)
    if(_libusb_type STREQUAL "SHARED_LIBRARY")
        add_custom_command(TARGET libusb_package_consumer POST_BUILD
            COMMAND "${CMAKE_COMMAND}" -E copy_if_different
                "$<TARGET_FILE:libusb::usb-1.0>"
                "$<TARGET_FILE_DIR:libusb_package_consumer>"
        )
    endif()
endif()

enable_testing()
add_test(NAME run_libusb_package_consumer COMMAND libusb_package_consumer)
