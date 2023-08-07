# libusb-cmake

This is the _**community**-supported_ CMake build system for [libusb] project.

The _officially-supported_ build system for [libusb] remains Autotools, as part of the [libusb] main repo.

NOTE: [libusb/](libusb/) subfolder is a git [subtree](https://www.atlassian.com/git/tutorials/git-subtree). Do not attempt to contribute to it - use an upstream [libusb] repo for that purpose.

## Use cases

The main use case as of this moment - using libusb as a [subdirectory](https://cmake.org/cmake/help/latest/command/add_subdirectory.html). Depending on the needs of the host project `libusb` may be built with different options, with or w/o installing binaries, etc. 

---

More details: TBD.

[libusb]: https://github.com/libusb/libusb
