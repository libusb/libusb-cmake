#include <stdio.h>

#include <emscripten.h>
#include <libusb.h>

EM_JS(void, install_webusb_mock, (), {
	if (typeof globalThis.navigator === 'undefined') {
		Object.defineProperty(globalThis, 'navigator', {
			configurable: true,
			value: {}
		});
	}
	Object.defineProperty(globalThis.navigator, 'usb', {
		configurable: true,
		value: {
			getDevices: function() {
				return new Promise(function(resolve) {
					setTimeout(function() { resolve([]); }, 0);
				});
			}
		}
	});
});

int main(void)
{
	libusb_context *ctx = NULL;
	libusb_device **devices = NULL;
	ssize_t count;
	int status;

	install_webusb_mock();
	status = libusb_init_context(&ctx, NULL, 0);
	if (status != LIBUSB_SUCCESS) {
		fprintf(stderr, "libusb_init_context failed: %s\n",
			libusb_error_name(status));
		return 1;
	}

	count = libusb_get_device_list(ctx, &devices);
	if (devices)
		libusb_free_device_list(devices, 1);
	libusb_exit(ctx);

	if (count != 0) {
		fprintf(stderr, "expected no WebUSB devices, got %ld\n", (long)count);
		return 1;
	}

	return 0;
}
