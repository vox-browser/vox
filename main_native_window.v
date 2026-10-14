module main

import gg
import sokol.sapp
import time

// The macOS shell draws directly into its Cocoa view. GG's default lifecycle
// also creates GPU shaders, pipelines and a FreeType atlas that this renderer
// never uses. Retain its event/frame callbacks and initialize only their shared
// context state before handing control to the browser's own window callback.
fn configure_native_browser_context(mut context gg.Context) {
	$if macos {
		if !context.native_rendering {
			return
		}
		context.window.init_userdata_cb = initialize_native_browser_context
		context.window.cleanup_userdata_cb = cleanup_native_browser_context
	}
}

fn native_browser_context_scale(reported_scale f32) f32 {
	return if reported_scale < 0.1 { f32(1) } else { reported_scale }
}

fn initialize_native_browser_context(user_data voidptr) {
	mut context := unsafe { &gg.Context(user_data) }
	if context.has_started {
		return
	}
	context.scale = native_browser_context_scale(sapp.dpi_scale())
	context.timer = time.new_stopwatch()
	context.update_timer = time.new_stopwatch()
	if context.config.init_fn != unsafe { nil } {
		context.config.init_fn(context.user_data)
	}
	context.has_started = true
}

fn cleanup_native_browser_context(user_data voidptr) {
	mut context := unsafe { &gg.Context(user_data) }
	if !context.has_started {
		return
	}
	if context.config.cleanup_fn != unsafe { nil } {
		context.config.cleanup_fn(context.user_data)
	}
	context.has_started = false
}
