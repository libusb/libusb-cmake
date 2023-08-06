project(examples
    VERSION ${LIBUSB_VERSION}
    LANGUAGES C
)

get_filename_component(EXAMPLES_ROOT "${LIBUSB_ROOT}/../examples" ABSOLUTE)

if(MSVC)
    add_library(getoptMSVC STATIC
        "${LIBUSB_ROOT}/../msvc/getopt/getopt.c"
        "${LIBUSB_ROOT}/../msvc/getopt/getopt.h"
        "${LIBUSB_ROOT}/../msvc/getopt/getopt1.c"
    )
    # Need to pass HAVE_CONFIG_H so getopt.h can load the config header
    target_compile_definitions(getoptMSVC PRIVATE HAVE_CONFIG_H)
    target_include_directories(getoptMSVC
        PUBLIC "${LIBUSB_ROOT}/../msvc/getopt/"
        PRIVATE "${LIBUSB_GEN_INCLUDES}"
    )
endif()

function(add_libusb_example TEST_NAME)
    set(SOURCES)
    foreach(SOURCE_NAME ${ARGN})
        list(APPEND SOURCES "${EXAMPLES_ROOT}/${SOURCE_NAME}")
    endforeach()
    add_executable("${TEST_NAME}" ${SOURCES})
    target_include_directories("${TEST_NAME}" PRIVATE "${LIBUSB_GEN_INCLUDES}")
    target_link_libraries("${TEST_NAME}" PRIVATE usb-1.0)
    target_compile_definitions("${TEST_NAME}" PRIVATE $<$<C_COMPILER_ID:MSVC>:_CRT_SECURE_NO_WARNINGS=1>)
endfunction()

add_libusb_example(listdevs "listdevs.c")

add_libusb_example(dpfp "dpfp.c")

add_libusb_example(hotplugtest "hotplugtest.c")

add_libusb_example(fxload
    "ezusb.c"
    "ezusb.h"
    "fxload.c"
)
target_link_libraries(fxload PRIVATE $<$<C_COMPILER_ID:MSVC>:getoptMSVC>)

add_libusb_example(testlibusb "testlibusb.c")

add_libusb_example(sam3u_benchmark "sam3u_benchmark.c")

add_libusb_example(xusb "xusb.c")
