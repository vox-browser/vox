module main

#include "@VMODROOT/native/include/native_redraw_test_darwin.h"

fn C.native_test_async_redraw_without_active_window() int

fn test_async_native_resource_redraw_uses_retained_window_without_main_or_key_window() {
	$if macos {
		assert C.native_test_async_redraw_without_active_window() == 31
	}
}
