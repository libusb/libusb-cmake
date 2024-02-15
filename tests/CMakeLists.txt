project(tests
    VERSION ${LIBUSB_VERSION}
    LANGUAGES C
)

get_filename_component(TESTS_ROOT "${LIBUSB_ROOT}/../tests" ABSOLUTE)

add_library(libusb_tests_build_interface INTERFACE)
target_link_libraries(libusb_tests_build_interface INTERFACE usb-1.0)
target_include_directories(libusb_tests_build_interface INTERFACE "${LIBUSB_GEN_INCLUDES}")
target_compile_definitions(libusb_tests_build_interface INTERFACE $<$<C_COMPILER_ID:MSVC>:_CRT_SECURE_NO_WARNINGS=1>)

function(add_libusb_test TEST_NAME)
    set(SOURCES "${TESTS_ROOT}/testlib.c")
    foreach(SOURCE_NAME ${ARGN})
        list(APPEND SOURCES "${TESTS_ROOT}/${SOURCE_NAME}")
    endforeach()
    add_executable(${TEST_NAME} ${SOURCES})
    target_link_libraries(${TEST_NAME} PRIVATE libusb_tests_build_interface)

    add_test(NAME ${TEST_NAME} COMMAND ${TEST_NAME})
    set_tests_properties(${TEST_NAME} PROPERTIES
      PASS_REGULAR_EXPRESSION "Failed 0 tests"
    )
    set_tests_properties(${TEST_NAME} PROPERTIES
      FAIL_REGULAR_EXPRESSION "Failed [1-9].*tests;Error in [1-9].*tests"
    )
endfunction()

add_libusb_test(stress "stress.c")

add_executable(stress_mt "${TESTS_ROOT}/stress_mt.c")
target_link_libraries(stress_mt PRIVATE libusb_tests_build_interface)
add_test(NAME stress_mt COMMAND stress_mt)

add_libusb_test(set_option "set_option.c")
add_libusb_test(init_context "init_context.c")

# the Darwin backend has special backdoor for this test,
# which is only available in static builds
if(APPLE AND NOT LIBUSB_BUILD_SHARED_LIBS)
    add_libusb_test(macos "macos.c")
endif()
