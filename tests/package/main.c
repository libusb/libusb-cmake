#include <stdio.h>

#include <libusb.h>

int main(void)
{
	const struct libusb_version *version = libusb_get_version();

	if (!version || !version->rc || !version->describe || !version->describe[0])
		return 1;

	printf("%u.%u.%u%s\n", version->major, version->minor,
	       version->micro, version->rc);
	return 0;
}
