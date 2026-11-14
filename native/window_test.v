module main

import gg
import dom
import sokol.sapp

fn test_portable_window_title_can_be_updated_before_sokol_window_creation() {
	$if macos { return }
	assert !sapp.isvalid()
	mut app := BrowserApp{
		ctx: gg.new_context(width: 960, height: 720)
		document: dom.Document.create(dom.url_about_blank())
	}
	// Process-tab children install their document before Sokol opens X11.
	app.update_window_title()
}

@[heap]
struct NativeBrowserContextTestState {
mut:
	context     &gg.Context = unsafe { nil }
	callbacks   []string
	initialized int
	cleaned_up  int
	width       int
	height      int
	key_code    int
	key_down    int
	key_up      int
}

fn native_browser_context_test_init(user_data voidptr) {
	mut state := unsafe { &NativeBrowserContextTestState(user_data) }
	assert !state.context.has_started
	assert state.context.scale >= 0.1
	assert state.context.timer.start > 0
	assert state.context.update_timer.start > 0
	assert !state.context.font_inited
	assert state.context.ft == unsafe { nil }
	assert state.context.pipeline == unsafe { nil }
	state.initialized++
	state.callbacks << 'init'
}

fn native_browser_context_test_cleanup(user_data voidptr) {
	mut state := unsafe { &NativeBrowserContextTestState(user_data) }
	assert state.context.has_started
	assert state.initialized == 1
	assert state.context.ft == unsafe { nil }
	assert state.context.pipeline == unsafe { nil }
	state.cleaned_up++
	state.callbacks << 'cleanup'
}

fn test_native_browser_context_uses_cocoa_lifecycle_without_gpu_or_font_setup() {
	$if macos {
		mut state := &NativeBrowserContextTestState{}
		mut context := gg.new_context(
			native_rendering: true
			user_data:        state
			init_fn:          native_browser_context_test_init
			cleanup_fn:       native_browser_context_test_cleanup
		)
		state.context = context
		original_frame := context.window.frame_userdata_cb
		original_event := voidptr(context.window.event_userdata_cb)
		context.window.sample_count = 4
		configure_native_browser_context(mut context)
		assert context.window.sample_count == 1
		assert context.config.swap_interval == 0
		assert context.window.swap_interval == 1
		assert context.window.frame_userdata_cb == original_frame
		assert voidptr(context.window.event_userdata_cb) != original_event
		assert !context.has_started
		context.window.cleanup_userdata_cb(context)
		assert state.callbacks.len == 0
		context.window.init_userdata_cb(context)
		context.window.init_userdata_cb(context)
		assert context.has_started
		assert state.initialized == 1
		assert state.cleaned_up == 0
		assert state.callbacks == ['init']
		context.window.cleanup_userdata_cb(context)
		context.window.cleanup_userdata_cb(context)
		assert !context.has_started
		assert state.cleaned_up == 1
		assert state.callbacks == ['init', 'cleanup']
		assert !context.font_inited
		assert context.ft == unsafe { nil }
		assert context.pipeline == unsafe { nil }
	}
}

fn test_native_browser_context_preserves_other_renderers_callbacks() {
	mut context := gg.new_context(native_rendering: false)
	original_init := context.window.init_userdata_cb
	original_cleanup := context.window.cleanup_userdata_cb
	original_frame := context.window.frame_userdata_cb
	original_event := voidptr(context.window.event_userdata_cb)
	context.window.sample_count = 4
	configure_native_browser_context(mut context)
	assert context.window.sample_count == 4
	assert context.config.swap_interval == 1
	assert context.window.init_userdata_cb == original_init
	assert context.window.cleanup_userdata_cb == original_cleanup
	assert context.window.frame_userdata_cb == original_frame
	$if macos {
		assert voidptr(context.window.event_userdata_cb) == original_event
	} $else {
		assert voidptr(context.window.event_userdata_cb) != original_event
	}
	assert !context.has_started
}

fn test_native_browser_context_preserves_native_callbacks_on_other_platforms() {
	$if !macos {
		mut context := gg.new_context(native_rendering: true)
		original_init := context.window.init_userdata_cb
		original_cleanup := context.window.cleanup_userdata_cb
		configure_native_browser_context(mut context)
		assert context.window.init_userdata_cb == original_init
		assert context.window.cleanup_userdata_cb == original_cleanup
	}
}

fn test_native_browser_context_scale_falls_back_before_a_window_is_available() {
	assert native_browser_context_scale(0) == 1
	assert native_browser_context_scale(-1) == 1
	assert native_browser_context_scale(0.05) == 1
	assert native_browser_context_scale(1) == 1
	assert native_browser_context_scale(2) == 2
	assert native_browser_context_scale(1.5) == 1.5
}

fn test_native_browser_context_without_user_callbacks_initializes_and_cleans_up() {
	$if macos {
		mut context := gg.new_context(native_rendering: true)
		configure_native_browser_context(mut context)
		context.window.init_userdata_cb(context)
		assert context.has_started
		assert context.scale >= 0.1
		context.window.cleanup_userdata_cb(context)
		assert !context.has_started
	}
}

fn native_browser_context_test_resize_event(event &gg.Event, user_data voidptr) {
	mut state := unsafe { &NativeBrowserContextTestState(user_data) }
	assert event.typ == .resized
	assert state.context.width == state.width
	assert state.context.height == state.height
	state.callbacks << 'event'
}

fn native_browser_context_test_resized(event &gg.Event, user_data voidptr) {
	mut state := unsafe { &NativeBrowserContextTestState(user_data) }
	assert state.context.width == event.window_width
	assert state.context.height == event.window_height
	assert state.context.window.width == event.window_width
	assert state.context.window.height == event.window_height
	assert state.context.scale >= 0.1
	assert state.context.ft == unsafe { nil }
	assert state.context.pipeline == unsafe { nil }
	state.width = event.window_width
	state.height = event.window_height
	state.callbacks << 'resized'
}

fn test_native_browser_maximize_restore_and_resize_without_a_font_atlas() {
	$if !macos { return }
	mut state := &NativeBrowserContextTestState{width: 800, height: 680}
	mut context := gg.new_context(
		width: state.width
		height: state.height
		native_rendering: true
		user_data: state
		event_fn: native_browser_context_test_resize_event
		resized_fn: native_browser_context_test_resized
	)
	state.context = context
	configure_native_browser_context(mut context)
	context.window.init_userdata_cb(context)
	defer { context.window.cleanup_userdata_cb(context) }
	for size in [[1920, 1080], [800, 680], [2560, 1440], [640, 480]] {
		mut event := sapp.Event{type: .resized, window_width: size[0], window_height: size[1]}
		context.window.event_userdata_cb(&event, context)
		assert event.type == .resized
		assert state.width == size[0]
		assert state.height == size[1]
	}
	assert state.callbacks == ['event', 'resized', 'event', 'resized', 'event', 'resized', 'event', 'resized']
}

fn test_native_browser_resize_supports_on_event_and_absent_resize_hooks() {
	$if !macos { return }
	mut state := &NativeBrowserContextTestState{width: 800, height: 680}
	mut context := gg.new_context(
		width: state.width
		height: state.height
		native_rendering: true
		user_data: state
		on_event: fn (user_data voidptr, event &gg.Event) {
			native_browser_context_test_resize_event(event, user_data)
		}
	)
	state.context = context
	configure_native_browser_context(mut context)
	context.window.init_userdata_cb(context)
	defer { context.window.cleanup_userdata_cb(context) }
	mut event := sapp.Event{type: .resized, window_width: 1600, window_height: 900}
	context.window.event_userdata_cb(&event, context)
	assert state.callbacks == ['event']
	assert context.width == 1600
	assert context.height == 900
	assert context.ft == unsafe { nil }
	assert !context.font_inited
}

fn test_native_browser_resize_adapter_preserves_gg_keyboard_and_pointer_dispatch() {
	$if !macos { return }
	mut state := &NativeBrowserContextTestState{}
	mut context := gg.new_context(
		native_rendering: true
		user_data: state
		event_fn: fn (event &gg.Event, user_data voidptr) {
			mut state := unsafe { &NativeBrowserContextTestState(user_data) }
			assert event.window_width == 1600
			assert event.window_height == 900
			assert event.framebuffer_width == 3200
			assert event.framebuffer_height == 1800
			state.callbacks << 'event:${event.typ}'
		}
		keydown_fn: fn (key gg.KeyCode, modifiers gg.Modifier, user_data voidptr) {
			mut state := unsafe { &NativeBrowserContextTestState(user_data) }
			assert key == .l
			assert modifiers.has(.super)
			state.callbacks << 'keydown'
		}
		click_fn: fn (x f32, y f32, button gg.MouseButton, user_data voidptr) {
			mut state := unsafe { &NativeBrowserContextTestState(user_data) }
			assert x == 12
			assert y == 18
			assert button == .left
			state.callbacks << 'click'
		}
	)
	state.context = context
	configure_native_browser_context(mut context)
	context.window.init_userdata_cb(context)
	defer { context.window.cleanup_userdata_cb(context) }
	context.scale = 2
	mut key := sapp.Event{type: .key_down, key_code: .l, modifiers: u32(gg.Modifier.super), window_width: 1600, window_height: 900, framebuffer_width: 3200, framebuffer_height: 1800}
	context.window.event_userdata_cb(&key, context)
	assert context.pressed_keys[int(gg.KeyCode.l)]
	mut click := sapp.Event{type: .mouse_down, mouse_button: .left, mouse_x: 24, mouse_y: 36, window_width: 1600, window_height: 900, framebuffer_width: 3200, framebuffer_height: 1800}
	context.window.event_userdata_cb(&click, context)
	assert context.mouse_pos_x == 12
	assert context.mouse_pos_y == 18
	assert state.callbacks == ['event:key_down', 'keydown', 'event:mouse_down', 'click']
	assert context.ft == unsafe { nil }
}

fn test_native_browser_event_adapter_preserves_full_width_key_codes() {
	mut state := &NativeBrowserContextTestState{}
	mut context := gg.new_context(
		native_rendering: true
		user_data: state
		event_fn: fn (event &gg.Event, user_data voidptr) {
			state := unsafe { &NativeBrowserContextTestState(user_data) }
			if event.typ == .char {
				// GG synthesizes Enter's character event on Win32/X11.
				assert state.key_code == 257
				assert event.key_code == .invalid
				assert event.char_code == 13
			} else {
				assert int(event.key_code) == state.key_code
			}
			assert event.window_width == 960
			assert event.window_height == 720
			assert event.framebuffer_width == 1920
			assert event.framebuffer_height == 1440
		}
		keydown_fn: fn (key gg.KeyCode, modifiers gg.Modifier, user_data voidptr) {
			mut state := unsafe { &NativeBrowserContextTestState(user_data) }
			assert int(key) == state.key_code
			assert browser_tab_shortcut(key, modifiers) == ''
			state.key_down++
		}
		keyup_fn: fn (key gg.KeyCode, modifiers gg.Modifier, user_data voidptr) {
			mut state := unsafe { &NativeBrowserContextTestState(user_data) }
			assert int(key) == state.key_code
			state.key_up++
		}
	)
	configure_native_browser_context(mut context)
	context.scale = 1
	// Use numeric Sokol values so an enum-width regression cannot narrow both
	// the event under test and its expected value to the same incorrect key.
	for code in [256, 257, 262, 263, 340, 341, 342, 343, 344, 345, 346, 347] {
		state.key_code = code
		for event_type in [sapp.EventType.key_down, .key_up] {
			event := sapp.Event{
				type: event_type
				key_code: unsafe { sapp.KeyCode(code) }
				modifiers: if code in [343, 347] { u32(gg.Modifier.super) } else { u32(0) }
				window_width: 960
				window_height: 720
				framebuffer_width: 1920
				framebuffer_height: 1440
			}
			assert int(event.key_code) == code
			assert event.type == event_type
			context.window.event_userdata_cb(&event, context)
			assert context.pressed_keys[code] == (event_type == .key_down)
			assert !context.pressed_keys[87]
		}
	}
	assert state.key_down == 12
	assert state.key_up == 12
}
