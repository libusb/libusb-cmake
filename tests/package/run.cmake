foreach(_variable
        TEST_BUILD_DIR
        TEST_CMAKE_PACKAGE_DIR
        TEST_SOURCE_DIR
        TEST_ROOT
        TEST_GENERATOR)
    if(NOT DEFINED ${_variable} OR "${${_variable}}" STREQUAL "")
        message(FATAL_ERROR "${_variable} is required")
    endif()
endforeach()

if(NOT TEST_CROSSCOMPILING
        AND (NOT DEFINED TEST_CTEST_COMMAND OR TEST_CTEST_COMMAND STREQUAL ""))
    message(FATAL_ERROR "TEST_CTEST_COMMAND is required for native tests")
endif()

set(_install_prefix "${TEST_ROOT}/install")
file(REMOVE_RECURSE "${TEST_ROOT}")

set(_install_command
    "${CMAKE_COMMAND}" --install "${TEST_BUILD_DIR}"
    --prefix "${_install_prefix}"
)
if(TEST_CONFIG)
    list(APPEND _install_command --config "${TEST_CONFIG}")
endif()

execute_process(
    COMMAND ${_install_command}
    RESULT_VARIABLE _result
)
if(_result)
    message(FATAL_ERROR "Installing libusb for the package test failed: ${_result}")
endif()

if(IS_ABSOLUTE "${TEST_CMAKE_PACKAGE_DIR}")
    set(_legacy_package_dir "${TEST_CMAKE_PACKAGE_DIR}")
else()
    set(_legacy_package_dir "${_install_prefix}/${TEST_CMAKE_PACKAGE_DIR}")
endif()

function(libusb_test_installed_package _name _legacy)
    set(_consumer_build "${TEST_ROOT}/${_name}-build")
    set(_configure_command
        "${CMAKE_COMMAND}"
        -S "${TEST_SOURCE_DIR}"
        -B "${_consumer_build}"
        -G "${TEST_GENERATOR}"
        "-DCMAKE_PREFIX_PATH=${_install_prefix}"
    )

    if(TEST_PACKAGE_VERSION AND NOT _legacy)
        list(APPEND _configure_command
            "-DLIBUSB_REQUIRED_VERSION=${TEST_PACKAGE_VERSION}"
        )
    endif()
    if(_legacy)
        list(APPEND _configure_command
            -DLIBUSB_USE_LEGACY_TARGETS=ON
            "-DLIBUSB_LEGACY_PACKAGE_DIR=${_legacy_package_dir}"
        )
    endif()
    if(TEST_GENERATOR_PLATFORM)
        list(APPEND _configure_command -A "${TEST_GENERATOR_PLATFORM}")
    endif()
    if(TEST_GENERATOR_TOOLSET)
        list(APPEND _configure_command -T "${TEST_GENERATOR_TOOLSET}")
    endif()
    if(TEST_BUILD_TYPE)
        list(APPEND _configure_command "-DCMAKE_BUILD_TYPE=${TEST_BUILD_TYPE}")
    endif()
    if(TEST_TOOLCHAIN_FILE)
        list(APPEND _configure_command
            "-DCMAKE_TOOLCHAIN_FILE=${TEST_TOOLCHAIN_FILE}"
        )
    endif()
    if(TEST_ANDROID_ABI)
        list(APPEND _configure_command "-DANDROID_ABI=${TEST_ANDROID_ABI}")
    endif()
    if(TEST_ANDROID_PLATFORM)
        list(APPEND _configure_command
            "-DANDROID_PLATFORM=${TEST_ANDROID_PLATFORM}"
        )
    endif()

    execute_process(
        COMMAND ${_configure_command}
        RESULT_VARIABLE _result
    )
    if(_result)
        message(FATAL_ERROR
            "Configuring the ${_name} installed-package consumer failed: ${_result}"
        )
    endif()

    set(_build_command "${CMAKE_COMMAND}" --build "${_consumer_build}")
    if(TEST_CONFIG)
        list(APPEND _build_command --config "${TEST_CONFIG}")
    endif()

    execute_process(
        COMMAND ${_build_command}
        RESULT_VARIABLE _result
    )
    if(_result)
        message(FATAL_ERROR
            "Building the ${_name} installed-package consumer failed: ${_result}"
        )
    endif()

    if(NOT TEST_CROSSCOMPILING)
        set(_ctest_command "${TEST_CTEST_COMMAND}" --output-on-failure)
        if(TEST_CONFIG)
            list(APPEND _ctest_command -C "${TEST_CONFIG}")
        endif()

        execute_process(
            COMMAND ${_ctest_command}
            WORKING_DIRECTORY "${_consumer_build}"
            RESULT_VARIABLE _result
        )
        if(_result)
            message(FATAL_ERROR
                "Running the ${_name} installed-package consumer failed: ${_result}"
            )
        endif()
    endif()
endfunction()

libusb_test_installed_package(config OFF)
libusb_test_installed_package(legacy ON)
