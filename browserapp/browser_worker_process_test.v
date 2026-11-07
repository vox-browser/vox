module main

import os

$if darwin {
	#include <mach-o/dyld.h>
	fn C._dyld_get_image_name(u32) &char
}

fn test_script_worker_uses_the_actual_executable_when_an_injected_library_is_image_zero() {
	actual := browser_script_worker_executable()!
	assert os.real_path(actual) == os.real_path(os.args[0])
	assert os.is_executable(actual)
	$if darwin {
		if os.getenv('VOX_EXPECT_INJECTED_IMAGE_ZERO') == '1' {
			name := C._dyld_get_image_name(0)
			assert name != unsafe { nil }
			image_zero := unsafe { name.vstring() }.clone()
			assert image_zero.ends_with('.dylib')
			assert os.real_path(image_zero) != os.real_path(actual)
		}
	}
}
