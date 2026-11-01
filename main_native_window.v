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
	gg.set_window_title(browser_window_title(title))
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
		// Cocoa/Sokol already schedules native draws. GG's software limiter also
		// runs for the unused parent callback and can make the child wait twice.
		context.config = gg.Config{ ...context.config, swap_interval: 0 }
		C.native_install_browser_layer_presentation()
		context.window.init_userdata_cb = initialize_native_browser_context
		context.window.cleanup_userdata_cb = cleanup_native_browser_context
		context.window.event_userdata_cb = dispatch_native_browser_event
	}
}

fn dispatch_native_browser_event(event_pointer &sapp.Event, user_data voidptr) {
	// Sokol's C integer fields are 32-bit; GG's V integers can be 64-bit.
	// Copy fields instead of aliasing incompatible event layouts.
	event := gg.Event{
		frame_count: event_pointer.frame_count
		typ: event_pointer.type
		key_code: gg.KeyCode(event_pointer.key_code)
		char_code: event_pointer.char_code
		key_repeat: event_pointer.key_repeat
		modifiers: event_pointer.modifiers
		mouse_button: gg.MouseButton(event_pointer.mouse_button)
		mouse_x: event_pointer.mouse_x
		mouse_y: event_pointer.mouse_y
		mouse_dx: event_pointer.mouse_dx
		mouse_dy: event_pointer.mouse_dy
		scroll_x: event_pointer.scroll_x
		scroll_y: event_pointer.scroll_y
		num_touches: event_pointer.num_touches
		touches: event_pointer.touches
		window_width: event_pointer.window_width
		window_height: event_pointer.window_height
		framebuffer_width: event_pointer.framebuffer_width
		framebuffer_height: event_pointer.framebuffer_height
	}
	if event.typ != .resized {
		C.gg__gg_event_fn(&event, user_data)
		return
	}
	mut context := unsafe { &gg.Context(user_data) }
	// GG's resize path unconditionally updates ft.scale. The Cocoa lifecycle
	// deliberately leaves ft nil; only the shared dimensions and scale apply.
	// Preserve GG's ordering: general event callback, cached size, resize hook.
	if context.config.event_fn != unsafe { nil } {
		context.config.event_fn(&event, context.user_data)
	} else if context.config.on_event != unsafe { nil } {
		context.config.on_event(context.user_data, &event)
	}
	context.scale = native_browser_context_scale(sapp.dpi_scale())
	context.width = event.window_width
	context.height = event.window_height
	context.window.width = event.window_width
	context.window.height = event.window_height
	if context.config.resized_fn != unsafe { nil } {
		context.config.resized_fn(&event, context.user_data)
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
	$if macos {
		if sapp.isvalid() {
			restore_browser_window_state(sapp.macos_get_window())
			install_browser_history_swipe(sapp.macos_get_window(), context.user_data)
		}
	}
	mut app := unsafe { &BrowserApp(context.user_data) }
	app.start_process_tabs()
}

fn cleanup_native_browser_context(user_data voidptr) {
	mut context := unsafe { &gg.Context(user_data) }
	if !context.has_started {
		return
	}
	$if macos {
		C.native_history_swipe_remove()
		finish_browser_window_state()
	}
	if context.config.cleanup_fn != unsafe { nil } {
		context.config.cleanup_fn(context.user_data)
	}
	context.has_started = false
}
