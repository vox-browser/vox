module main

import gg

@[heap]
struct NativeBrowserContextTestState {
mut:
	context     &gg.Context = unsafe { nil }
	callbacks   []string
	initialized int
	cleaned_up  int
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
		original_event := context.window.event_userdata_cb
		configure_native_browser_context(mut context)
		assert context.window.frame_userdata_cb == original_frame
		assert context.window.event_userdata_cb == original_event
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
	original_event := context.window.event_userdata_cb
	configure_native_browser_context(mut context)
	assert context.window.init_userdata_cb == original_init
	assert context.window.cleanup_userdata_cb == original_cleanup
	assert context.window.frame_userdata_cb == original_frame
	assert context.window.event_userdata_cb == original_event
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
