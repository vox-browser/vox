module main

import gg
import processmetrics
import sokol.sapp
import time

$if macos {
	import browserwindow
}

#flag darwin -framework IOSurface

fn C.native_configure_browser_drawables()
fn C.native_install_browser_layer_presentation()
fn C.native_set_opaque_browser_frames(i32)
fn C.native_set_load_stage_callbacks(fn (&char) u64, fn (u64))

// Dispatch GG input events without calling its private C entry point.
// V HEAD moved gg's event dispatcher and no longer exposes
// `gg__gg_event_fn` to other modules (production build failure:
// `call to undeclared function 'gg__gg_event_fn'`). This mirrors
// gg's `gg_event_fn` using only public Context/Config fields so it
// keeps working across V revisions. Behavior matches upstream:
// ui-mode refresh, mouse-button mask tracking, scale-normalized
// coordinates, pressed-key edges, general event callback, per-type
// hooks, resize dimension caching (ft Atlas update guarded for the
// nil-atlas macOS shell), and Win32/X11 control-key char emulation.
fn dispatch_gg_event(mut event gg.Event, user_data voidptr) {
	mut context := unsafe { &gg.Context(user_data) }
	if context.ui_mode {
		context.refresh_ui()
	}
	if event.typ == .mouse_down {
		bitplace := int(event.mouse_button)
		context.mbtn_mask |= u8(1 << bitplace)
		context.mouse_buttons = unsafe { gg.MouseButtons(context.mbtn_mask) }
	}
	if event.typ == .mouse_up {
		bitplace := int(event.mouse_button)
		context.mbtn_mask &= ~(u8(1 << bitplace))
		context.mouse_buttons = unsafe { gg.MouseButtons(context.mbtn_mask) }
	}
	if event.typ == .mouse_move && event.mouse_button == .invalid {
		if context.mbtn_mask & 0x01 > 0 {
			event.mouse_button = .left
		}
		if context.mbtn_mask & 0x02 > 0 {
			event.mouse_button = .right
		}
		if context.mbtn_mask & 0x04 > 0 {
			event.mouse_button = .middle
		}
	}
	event.mouse_x /= context.scale
	event.mouse_y /= context.scale
	event.mouse_dx /= context.scale
	event.mouse_dy /= context.scale
	event.scroll_x /= context.scale
	event.scroll_y /= context.scale
	context.mouse_pos_x = int(event.mouse_x)
	context.mouse_pos_y = int(event.mouse_y)
	context.mouse_dx = int(event.mouse_dx)
	context.mouse_dy = int(event.mouse_dy)
	context.scroll_x = int(event.scroll_x)
	context.scroll_y = int(event.scroll_y)
	context.key_modifiers = unsafe { gg.Modifier(event.modifiers) }
	context.key_repeat = event.key_repeat
	if event.typ in [.key_down, .key_up] {
		// Mirrors gg's `key_code_max` (512, private to gg).
		key_idx := int(event.key_code) % 512
		prev := context.pressed_keys[key_idx]
		next := event.typ == .key_down
		context.pressed_keys[key_idx] = next
		context.pressed_keys_edge[key_idx] = prev != next
	}
	if context.config.event_fn != unsafe { nil } {
		context.config.event_fn(&event, context.user_data)
	} else if context.config.on_event != unsafe { nil } {
		context.config.on_event(context.user_data, &event)
	}
	match event.typ {
		.mouse_move {
			if context.config.move_fn != unsafe { nil } {
				context.config.move_fn(event.mouse_x, event.mouse_y, context.user_data)
			}
		}
		.mouse_down {
			if context.config.click_fn != unsafe { nil } {
				context.config.click_fn(event.mouse_x, event.mouse_y, event.mouse_button,
					context.user_data)
			}
		}
		.mouse_up {
			if context.config.unclick_fn != unsafe { nil } {
				context.config.unclick_fn(event.mouse_x, event.mouse_y, event.mouse_button,
					context.user_data)
			}
		}
		.mouse_leave {
			if context.config.leave_fn != unsafe { nil } {
				context.config.leave_fn(&event, context.user_data)
			}
		}
		.mouse_enter {
			if context.config.enter_fn != unsafe { nil } {
				context.config.enter_fn(&event, context.user_data)
			}
		}
		.mouse_scroll {
			if context.config.scroll_fn != unsafe { nil } {
				context.config.scroll_fn(&event, context.user_data)
			}
		}
		.key_down {
			if context.config.keydown_fn != unsafe { nil } {
				context.config.keydown_fn(event.key_code, unsafe { gg.Modifier(event.modifiers) },
					context.user_data)
			}
		}
		.key_up {
			if context.config.keyup_fn != unsafe { nil } {
				context.config.keyup_fn(event.key_code, unsafe { gg.Modifier(event.modifiers) },
					context.user_data)
			}
		}
		.char {
			if context.config.char_fn != unsafe { nil } {
				context.config.char_fn(event.char_code, context.user_data)
			}
		}
		.resized {
			context.scale = native_browser_context_scale(sapp.dpi_scale())
			if context.ft != unsafe { nil } {
				context.ft.scale = context.scale
			}
			context.width = event.window_width
			context.height = event.window_height
			context.window.width = event.window_width
			context.window.height = event.window_height
			if context.config.resized_fn != unsafe { nil } {
				context.config.resized_fn(&event, context.user_data)
			}
		}
		.quit_requested {
			if context.config.quit_fn != unsafe { nil } {
				context.config.quit_fn(&event, context.user_data)
			}
		}
		else {}
	}
	$if windows || ((linux || freebsd || openbsd || netbsd || dragonfly || solaris) && !sokol_wayland ?) {
		if event.typ == .key_down && event.key_code in [.backspace, .delete, .enter, .tab] {
			event.char_code = match event.key_code {
				.backspace { u32(8) }
				.tab { 9 }
				.enter { 13 }
				.delete { 127 }
				else { u32(event.key_code) }
			}
			event.key_code = .invalid
			event.typ = .char
			if context.config.event_fn != unsafe { nil } {
				context.config.event_fn(&event, context.user_data)
			} else if context.config.on_event != unsafe { nil } {
				context.config.on_event(context.user_data, &event)
			}
			if context.config.char_fn != unsafe { nil } {
				context.config.char_fn(event.char_code, context.user_data)
			}
		}
	}
}

fn (app &BrowserApp) update_window_title() {
	// Sokol's X11 title setter requires a live Display and Window. Documents
	// are also installed before window creation and in non-windowed modes.
	if app.ctx == unsafe { nil } || app.document == unsafe { nil } || !app.is_active_browser_tab() { return }
	$if !macos {
		if !sapp.isvalid() { return }
	}
	$if linux { initialize_linux_window_identity() }
	title := document_title(app.document)
	gg.set_window_title(browser_window_title(title))
}

// The macOS shell draws directly into its Cocoa view. GG's default lifecycle
// also creates GPU shaders, pipelines and a FreeType atlas that this renderer
// never uses. Retain its input/frame behavior and initialize only their shared
// context state before handing control to the browser's own window callback.
fn configure_native_browser_context(mut context gg.Context) {
	// Sokol's C event layout is narrower than GG's V event on current V.
	// Convert it before GG reads dimensions on every platform.
	$if !macos {
		context.window.event_userdata_cb = dispatch_native_browser_event
	}
	$if macos {
		// Runs before the window exists; AppKit reads this when indexing it.
		browserwindow.register_window_tab_indexing_default()
		if !context.native_rendering {
			return
		}
		// A tab joining an existing window starts hidden. Keep it out of the
		// Dock and the application switcher until its group shows it;
		// initialize_native_browser_context finishes the launch.
		if joins_process_tab_group() {
			browserwindow.begin_tab_process_launch()
		}
		if processmetrics.load_stages_enabled() {
			C.native_set_load_stage_callbacks(processmetrics.begin_native_instruction_stage,
				processmetrics.finish_native_instruction_stage)
		}
		$if vox_ui2 ? {
			// UI2 supplies the top row; retain native window capabilities without
			// constructing AppKit's hidden title bar first.
			context.window.borderless_window = browserwindow.configure_window_host()
		}
		// The Cocoa child paints the browser. Its MetalKit parent still starts
		// before our init callback, so avoid allocating its unused MSAA target.
		context.window.sample_count = 1
		// Cocoa/Sokol already schedules native draws. GG's software limiter also
		// runs for the unused parent callback and can make the child wait twice.
		context.config = gg.Config{ ...context.config, swap_interval: 0 }
		C.native_install_browser_layer_presentation()
		// draw() initializes the entire native frame before end_browser_frame:
		// opaque clear/replay, restored scroll pixels, or a retained snapshot.
		C.native_set_opaque_browser_frames(1)
		context.window.init_userdata_cb = initialize_native_browser_context
		context.window.cleanup_userdata_cb = cleanup_native_browser_context
		context.window.event_userdata_cb = dispatch_native_browser_event
	}
}

fn dispatch_native_browser_event(event_pointer &sapp.Event, user_data voidptr) {
	stage := processmetrics.begin_instruction_stage('native_input_delivery')
	defer { stage.finish() }
	// Sokol's C integer fields are 32-bit; GG's V integers can be 64-bit.
	// Copy fields instead of aliasing incompatible event layouts.
	mut event := gg.Event{
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
		dispatch_gg_event(mut event, user_data)
		return
	}
	$if !macos {
		// The portable renderer owns a normal GG font atlas and resize path.
		dispatch_gg_event(mut event, user_data)
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
	stage := processmetrics.begin_instruction_stage('native_window_initialization')
	defer { stage.finish() }
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
	// A windowless GG lifecycle can have no BrowserApp owner (including the
	// adapter tests). Process tabs require the live Sokol window in any case.
	if context.user_data != unsafe { nil } && sapp.isvalid() {
		mut app := unsafe { &BrowserApp(context.user_data) }
		app.start_process_tabs()
	}
	$if macos {
		// A joining tab ends its accessory launch in prepare_tab_window. If it
		// did not join (or no window exists), it becomes a regular app here.
		browserwindow.finish_tab_process_launch()
	}
}

fn cleanup_native_browser_context(user_data voidptr) {
	mut context := unsafe { &gg.Context(user_data) }
	if !context.has_started {
		return
	}
	$if macos {
		browserwindow.remove_history_swipe()
		finish_browser_window_state()
	}
	if context.config.cleanup_fn != unsafe { nil } {
		context.config.cleanup_fn(context.user_data)
	}
	context.has_started = false
}
