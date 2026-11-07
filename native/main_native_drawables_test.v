module main

#include "@VMODROOT/native_drawables_test_darwin.h"

fn C.native_test_unused_metal_drawable_configuration() int

fn test_native_cocoa_browser_releases_unused_parent_metal_drawables() {
	$if macos {
		assert C.native_test_unused_metal_drawable_configuration() == 31
	}
}
