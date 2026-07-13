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

All integration modes expose `libusb::usb-1.0`. Linking it supplies the required
include paths and platform libraries; include the API as `#include <libusb.h>`.
The source-only `usb-1.0` target remains available for compatibility.

### Vendored source

Place this repository in the source tree, for example under
`third_party/libusb-cmake`:

```cmake
set(LIBUSB_INSTALL_TARGETS OFF)
add_subdirectory(third_party/libusb-cmake)

add_executable(my_app main.c)
target_link_libraries(my_app PRIVATE libusb::usb-1.0)
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
target_link_libraries(my_app PRIVATE libusb::usb-1.0)
```

`FetchContent` downloads during CMake configuration. Vendor the repository when
configuration must work without network access.

### Standalone build and install

```console
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/path/to/install -DLIBUSB_BUILD_SHARED_LIBS=ON
cmake --build build --config Release
cmake --install build --config Release
```

Configure with `-DLIBUSB_BUILD_SHARED_LIBS=OFF` for a static library. Add
`-DLIBUSB_BUILD_EXAMPLES=ON` or `-DLIBUSB_BUILD_TESTING=ON` at configuration
time to build the bundled examples or tests.

### Installed CMake package

Configure the consuming project with `-DCMAKE_PREFIX_PATH=/path/to/install`
when the installation prefix is not in a standard location, then use:

```cmake
find_package(libusb CONFIG REQUIRED)

add_executable(my_app main.c)
target_link_libraries(my_app PRIVATE libusb::usb-1.0)
```

`libusb::include` carries only the public include directory for targets that do
not link libusb. Normal consumers should use `libusb::usb-1.0`.

### pkg-config

The installed module uses the upstream name `libusb-1.0`. For a nonstandard
prefix, add its pkg-config directory to `PKG_CONFIG_PATH`:

```console
export PKG_CONFIG_PATH=/path/to/install/lib/pkgconfig
cc main.c -o my_app $(pkg-config --cflags --libs libusb-1.0)
```

Use `pkg-config --static` when linking the static archive so its private system
libraries are included. The `.pc` file records the configure-time install
prefix, so set `CMAKE_INSTALL_PREFIX` during configuration as shown above.

## CMake options

| Option | Default | Purpose |
| --- | --- | --- |
| `LIBUSB_BUILD_SHARED_LIBS` | Current `BUILD_SHARED_LIBS` value; `OFF` if false or unset | Build a shared instead of static library |
| `LIBUSB_BUILD_EXAMPLES` | `OFF` | Build bundled examples |
| `LIBUSB_BUILD_TESTING` | `OFF` | Build and register tests |
| `LIBUSB_INSTALL_TARGETS` | `ON` | Install the library, public header, and pkg-config metadata |
| `LIBUSB_EXPORT_INSTALL_TARGETS` | `ON` when installing | Install the CMake package config, target export, and version file |
| `LIBUSB_TARGETS_INCLUDE_USING_SYSTEM` | `ON` | Treat public libusb headers as system headers |
| `LIBUSB_ENABLE_LOGGING` | `ON` | Compile logging support |
| `LIBUSB_ENABLE_DEBUG_LOGGING` | `OFF` | Enable debug logging |
| `LIBUSB_ENABLE_UDEV` | `ON` on Linux | Use libudev instead of netlink |
| `LIBUSB_ENABLE_WINDOWS_HOTPLUG` | `OFF` on Windows | Enable the Windows hotplug backend |

Set options before `add_subdirectory()` or `FetchContent_MakeAvailable()`. When
the library type matters, set `LIBUSB_BUILD_SHARED_LIBS` explicitly; the global
`BUILD_SHARED_LIBS` value only supplies its initial default.

## Installed files

The default installation includes the library, `include/libusb-1.0/libusb.h`,
the `libusb` CMake package under the platform library directory, and
`${CMAKE_INSTALL_LIBDIR}/pkgconfig/libusb-1.0.pc`. The legacy
`usb-1.0-targets.cmake` filename is kept as a compatibility wrapper around
`libusb-targets.cmake`.

[libusb]: https://github.com/libusb/libusb
[subtree]: https://www.atlassian.com/git/tutorials/git-subtree
