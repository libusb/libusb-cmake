# libusb-cmake

Community-supported CMake build system for [libusb]. The officially supported
libusb build system remains Autotools in the upstream repository.

This repository is self-contained. Its [`libusb/`](libusb/) directory is
vendored from upstream; it was historically maintained as a git [subtree].
Send changes to the bundled library sources to [libusb], not here.

Maintainers can run the **Update libusb** workflow with an upstream branch,
tag, or full commit SHA. It imports the exact upstream tree, records the
revision in [.github/libusb-upstream.rev](.github/libusb-upstream.rev), and
opens a draft PR. This keeps updates compatible with the repository's required
linear history.

## Requirements

- CMake 3.16 or newer and a C compiler. Emscripten also requires a C++20
  compiler.
- On Linux, libudev development files are required by default. Set
  `LIBUSB_ENABLE_UDEV=OFF` to use the netlink backend instead.

Implemented platform backends are Windows desktop and Windows Store (UWP),
Linux, Android, macOS, NetBSD, OpenBSD, SunOS/illumos, and Emscripten/WebUSB.

## Use cases

Source-based integrations expose the `usb-1.0` target. Linking it supplies the
required include paths and platform libraries; include the API as
`#include <libusb.h>`.

### Vendored source

Place this repository in the source tree, for example under
`third_party/libusb-cmake`:

```cmake
set(LIBUSB_INSTALL_TARGETS OFF)
add_subdirectory(third_party/libusb-cmake)

add_executable(my_app main.c)
target_link_libraries(my_app PRIVATE usb-1.0)
```

Keep `LIBUSB_INSTALL_TARGETS` enabled if the host project should also install
libusb.

### FetchContent

Pin a repository tag or commit for reproducible builds:

```cmake
include(FetchContent)

set(LIBUSB_INSTALL_TARGETS OFF)
FetchContent_Declare(libusb_cmake
    GIT_REPOSITORY https://github.com/libusb/libusb-cmake.git
    GIT_TAG        v1.0.30-0
)
FetchContent_MakeAvailable(libusb_cmake)

add_executable(my_app main.c)
target_link_libraries(my_app PRIVATE usb-1.0)
```

`FetchContent` downloads during CMake configuration. Vendor the repository when
configuration must work without network access.

### Standalone build and install

```console
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DLIBUSB_BUILD_SHARED_LIBS=ON
cmake --build build --config Release
cmake --install build --config Release --prefix /path/to/install
```

Configure with `-DLIBUSB_BUILD_SHARED_LIBS=OFF` for a static library. Add
`-DLIBUSB_BUILD_EXAMPLES=ON` or `-DLIBUSB_BUILD_TESTING=ON` at configuration
time to build the bundled examples or tests.

## CMake options

| Option | Default | Purpose |
| --- | --- | --- |
| `LIBUSB_BUILD_SHARED_LIBS` | Current `BUILD_SHARED_LIBS` value; `OFF` if false or unset | Build a shared instead of static library |
| `LIBUSB_BUILD_EXAMPLES` | `OFF` | Build bundled examples |
| `LIBUSB_BUILD_TESTING` | `OFF` | Build and register tests |
| `LIBUSB_INSTALL_TARGETS` | `ON` | Install the library and public header |
| `LIBUSB_EXPORT_INSTALL_TARGETS` | `ON` when installing | Install CMake target export and version files |
| `LIBUSB_TARGETS_INCLUDE_USING_SYSTEM` | `ON` | Treat public libusb headers as system headers |
| `LIBUSB_ENABLE_LOGGING` | `ON` | Compile logging support |
| `LIBUSB_ENABLE_DEBUG_LOGGING` | `OFF` | Enable debug logging |
| `LIBUSB_ENABLE_UDEV` | `ON` on Linux | Use libudev instead of netlink |
| `LIBUSB_ENABLE_WINDOWS_HOTPLUG` | `OFF` on Windows | Enable the Windows hotplug backend |

Set options before `add_subdirectory()` or `FetchContent_MakeAvailable()`. When
the library type matters, set `LIBUSB_BUILD_SHARED_LIBS` explicitly; the global
`BUILD_SHARED_LIBS` value only supplies its initial default.

## Install status

With the default install/export options, installation emits the library,
`include/libusb-1.0/libusb.h`, a CMake target export, and a package version file.
No `libusb-config.cmake` or pkg-config file is generated, so this build does not
currently provide normal `find_package(libusb CONFIG)` or pkg-config
consumption. See [issue #38] and [issue #39]. Prefer source integration until
the package config is complete.

[libusb]: https://github.com/libusb/libusb
[subtree]: https://www.atlassian.com/git/tutorials/git-subtree
[issue #38]: https://github.com/libusb/libusb-cmake/issues/38
[issue #39]: https://github.com/libusb/libusb-cmake/issues/39
