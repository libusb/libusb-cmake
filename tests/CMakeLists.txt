project(tests
    VERSION ${LIBUSB_VERSION}
    LANGUAGES C
)

get_filename_component(TESTS_ROOT "${LIBUSB_ROOT}/../tests" ABSOLUTE)

add_library(libusb_tests_build_interface INTERFACE)
target_link_libraries(libusb_tests_build_interface INTERFACE libusb::usb-1.0)
target_include_directories(libusb_tests_build_interface INTERFACE "${LIBUSB_GEN_INCLUDES}")
target_compile_definitions(libusb_tests_build_interface INTERFACE $<$<C_COMPILER_ID:MSVC>:_CRT_SECURE_NO_WARNINGS=1>)

if(CMAKE_SYSTEM_NAME MATCHES "NetBSD|OpenBSD")
    find_package(Threads REQUIRED)
    target_link_libraries(libusb_tests_build_interface INTERFACE Threads::Threads)
endif()

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

# umockdev is a Linux-only test dependency.  As in libusb's Autotools build,
# discover it opportunistically so ordinary test builds do not require it.
if(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux")
    message(STATUS "Skipping umockdev test: it is supported only on Linux")
elseif(NOT LIBUSB_ENABLE_LOGGING)
    message(STATUS "Skipping umockdev test: it requires LIBUSB_ENABLE_LOGGING=ON")
elseif(LIBUSB_ENABLE_DEBUG_LOGGING)
    message(STATUS "Skipping umockdev test: it requires LIBUSB_ENABLE_DEBUG_LOGGING=OFF")
else()
    find_package(PkgConfig QUIET)
    if(NOT PkgConfig_FOUND)
        message(STATUS "Skipping umockdev test: PkgConfig was not found")
    else()
        pkg_check_modules(UMOCKDEV QUIET IMPORTED_TARGET "umockdev-1.0>=0.16.0")
        if(NOT UMOCKDEV_FOUND)
            message(STATUS "Skipping umockdev test: umockdev-1.0 >= 0.16.0 was not found")
        else()
            pkg_check_modules(UMOCKDEV_HOTPLUG QUIET "umockdev-1.0>=0.17.7")
            add_executable(umockdev "${TESTS_ROOT}/umockdev.c")
            target_link_libraries(umockdev PRIVATE libusb_tests_build_interface PkgConfig::UMOCKDEV)
            if(UMOCKDEV_HOTPLUG_FOUND)
                target_compile_definitions(umockdev PRIVATE UMOCKDEV_HOTPLUG=1)
            else()
                message(STATUS "umockdev test: hotplug add/remove subtest requires umockdev-1.0 >= 0.17.7")
            endif()
            # Keep libumockdev-preload on the link line while --as-needed is disabled.
            target_link_options(umockdev PRIVATE
                "LINKER:--push-state,--no-as-needed"
                "LINKER:-lumockdev-preload"
                "LINKER:--pop-state"
            )
            add_test(NAME umockdev COMMAND umockdev)
        endif()
    endif()
endif()

# the Darwin backend has special backdoor for this test,
# which is only available in static builds
if(APPLE AND NOT LIBUSB_BUILD_SHARED_LIBS)
    add_libusb_test(macos "macos.c")
endif()

if(LIBUSB_IS_TOP_LEVEL
        AND LIBUSB_INSTALL_TARGETS
        AND LIBUSB_EXPORT_INSTALL_TARGETS)
    add_test(NAME cmake_package
        COMMAND "${CMAKE_COMMAND}"
            "-DTEST_BUILD_DIR=${CMAKE_BINARY_DIR}"
            "-DTEST_CMAKE_PACKAGE_DIR=${CMAKE_INSTALL_LIBDIR}/cmake/libusb"
            "-DTEST_SOURCE_DIR=${CMAKE_CURRENT_LIST_DIR}/package"
            "-DTEST_ROOT=${CMAKE_CURRENT_BINARY_DIR}/package-test"
            "-DTEST_GENERATOR=${CMAKE_GENERATOR}"
            "-DTEST_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}"
            "-DTEST_GENERATOR_TOOLSET=${CMAKE_GENERATOR_TOOLSET}"
            "-DTEST_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
            "-DTEST_CONFIG=$<CONFIG>"
            "-DTEST_CROSSCOMPILING=${CMAKE_CROSSCOMPILING}"
            "-DTEST_CTEST_COMMAND=${CMAKE_CTEST_COMMAND}"
            "-DTEST_PACKAGE_VERSION=${LIBUSB_VERSION}"
            "-DTEST_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}"
            "-DTEST_ANDROID_ABI=${ANDROID_ABI}"
            "-DTEST_ANDROID_PLATFORM=${ANDROID_PLATFORM}"
            -P "${CMAKE_CURRENT_LIST_DIR}/package/run.cmake"
    )
endif()
