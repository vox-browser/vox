module main

import gg

fn test_native_paint_size_follows_constrained_cocoa_child() {
	$if !macos {
		return
	}
	mut context := gg.new_context(native_rendering: true)
	context.width = 1728
	context.height = 1040
	sync_native_browser_paint_size(mut context, gg.Size{1728, 1025})
	assert context.width == 1728
	assert context.height == 1025
	// A subsequent maximization or resize can change both dimensions.
	sync_native_browser_paint_size(mut context, gg.Size{1600, 900})
	assert context.width == 1600
	assert context.height == 900
	sync_native_browser_paint_size(mut context, gg.Size{})
	assert context.width == 1600
	assert context.height == 900
}

fn test_native_paint_size_preserves_portable_renderer_dimensions() {
	mut context := gg.new_context(native_rendering: false)
	context.width = 800
	context.height = 600
	sync_native_browser_paint_size(mut context, gg.Size{1728, 1025})
	assert context.width == 800
	assert context.height == 600
}
