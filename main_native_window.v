module main

import gg
import sokol.sapp
import time

fn C.native_configure_browser_drawables()
fn C.native_install_browser_layer_presentation()

// Keep GG's normal input dispatch for events that do not need its font atlas.
fn C.gg__gg_event_fn(voidptr, voidptr)

fn (app &BrowserApp) update_window_title() {
	// Sokol's X11 title setter requires a live Display and Window. Documents
	// are also installed before window creation and in non-windowed modes.
	if app.ctx == unsafe { nil } || app.document == unsafe { nil } || !app.is_active_browser_tab() { return }
	title := document_title(app.document)
	gg.set_window_title(if title != '' { '${title} — vox' } else { 'vox' })
}

// The macOS shell draws directly into its Cocoa view. GG's default lifecycle
// also creates GPU shaders, pipelines and a FreeType atlas that this renderer
// never uses. Retain its input/frame behavior and initialize only their shared
// context state before handing control to the browser's own window callback.
fn configure_native_browser_context(mut context gg.Context) {
	$if macos {
		if !context.native_rendering {
			return
		}
		// The Cocoa child paints the browser. Its MetalKit parent still starts
		// before our init callback, so avoid allocating its unused MSAA target.
		context.window.sample_count = 1
		C.native_install_browser_layer_presentation()
		context.window.init_userdata_cb = initialize_native_browser_context
		context.window.cleanup_userdata_cb = cleanup_native_browser_context
		context.window.event_userdata_cb = dispatch_native_browser_event
	}
}

fn dispatch_native_browser_event(event_pointer &sapp.Event, user_data voidptr) {
	event := unsafe { &gg.Event(event_pointer) }
	if event.typ != .resized {
		C.gg__gg_event_fn(event_pointer, user_data)
		return
	}
	mut context := unsafe { &gg.Context(user_data) }
	// GG's resize path unconditionally updates ft.scale. The Cocoa lifecycle
	// deliberately leaves ft nil; only the shared dimensions and scale apply.
	// Preserve GG's ordering: general event callback, cached size, resize hook.
	if context.config.event_fn != unsafe { nil } {
		context.config.event_fn(event, context.user_data)
	} else if context.config.on_event != unsafe { nil } {
		context.config.on_event(context.user_data, event)
	}
	context.scale = native_browser_context_scale(sapp.dpi_scale())
	context.width = event.window_width
	context.height = event.window_height
	context.window.width = event.window_width
	context.window.height = event.window_height
	if context.config.resized_fn != unsafe { nil } {
		context.config.resized_fn(event, context.user_data)
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
	$if macos {
		C.native_configure_browser_drawables()
	}
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
