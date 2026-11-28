// vtest build: macos
module main

import os

#include "@VMODROOT/chromium/opaque_continuation_test.h"

fn C.vox_test_opaque_continuation() i32

fn test_native_opaque_continuation_preserves_backdrop_and_scope_ownership() {
	old_delay := os.getenv_opt('LADYBIRD_SCREENSHOT_DELAY_SECONDS')
	old_scale := os.getenv_opt('LADYBIRD_SCREENSHOT_SCALE')
	os.setenv('LADYBIRD_SCREENSHOT_DELAY_SECONDS', '0', true)
	os.setenv('LADYBIRD_SCREENSHOT_SCALE', '1', true)
	defer {
		if value := old_delay {
			os.setenv('LADYBIRD_SCREENSHOT_DELAY_SECONDS', value, true)
		} else {
			os.unsetenv('LADYBIRD_SCREENSHOT_DELAY_SECONDS')
		}
		if value := old_scale {
			os.setenv('LADYBIRD_SCREENSHOT_SCALE', value, true)
		} else {
			os.unsetenv('LADYBIRD_SCREENSHOT_SCALE')
		}
	}
	assert C.vox_test_opaque_continuation() == 0
}
