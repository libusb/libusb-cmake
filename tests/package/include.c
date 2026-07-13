#include <stddef.h>

#include <libusb.h>

size_t libusb_version_size(void)
{
	return sizeof(struct libusb_version);
}
