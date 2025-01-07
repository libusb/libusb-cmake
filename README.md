# libusb-cmake fork

This is a fork of the _**community**-supported_ CMake build system for [libusb](https://github.com/libusb/libusb) project.

The _officially-supported_ build system for **libusb** remains Autotools, as part of the **libusb** main repo.

# Build

## Configure CMake

### MSVC
```bash
cmake -S . -B build -G "Visual Studio 17 2022" -DCMAKE_MSVC_RUNTIME_LIBRARY="MultiThreaded$<$<CONFIG:Debug>:Debug>" -DLIBUSB_ENABLE_LOGGING="OFF"
```
### Ninja
```bash
cmake -S . -B build -G "Ninja Multi-Config" -DLIBUSB_ENABLE_LOGGING="OFF"
```

## Build

### MSVC
```bash
cmake --build build --config Release --target ALL_BUILD -j28
```
### Ninja
```bash
cmake --build build --config Release --target generated
```

Libusb repo: https://github.com/libusb/libusb
