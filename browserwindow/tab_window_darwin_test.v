module browserwindow

import macos

struct TerminateCounts {
mut:
	asked int
}

const terminate_counts = &TerminateCounts{}

fn delegate_terminates_after_last_window(_self voidptr, _cmd voidptr, _app voidptr) bool {
	mut counts := unsafe { terminate_counts }
	counts.asked++
	return true
}

fn test_background_tab_window_is_inert_and_keeps_the_process_alive() {
	pool := macos.autorelease_pool_new()
	defer { macos.release(pool) }
	app := macos.msg_id(macos.get_class('NSApplication'), 'sharedApplication')
	delegate_class := runtime_class('VoxTabWindowTestDelegate', [
		RuntimeMethod{
			selector:       'applicationShouldTerminateAfterLastWindowClosed:'
			implementation: voidptr(delegate_terminates_after_last_window)
			types:          'B@:@'
		},
	])
	delegate := macos.msg_id(delegate_class, 'new')
	macos.msg_void1(app, 'setDelegate:', delegate)
	defer {
		macos.msg_void1(app, 'setDelegate:', nil_id())
		macos.release(delegate)
	}
	window := macos.msg_id_rect_u64_u64_bool(macos.alloc('NSWindow'),
		'initWithContentRect:styleMask:backing:defer:', macos.rect(40, 50, 800, 600),
		ns_window_style_titled, 2, false)
	macos.msg_void_bool(window, 'setReleasedWhenClosed:', false)
	prepare_tab_window(window)
	assert macos.msg_f64(window, 'alphaValue') == 0
	assert macos.msg_bool(window, 'ignoresMouseEvents')
	assert tab_window_frame(window) == frame_of(macos.msg_rect(window, 'frame'))
	policy := 'applicationShouldTerminateAfterLastWindowClosed:'
	// An ordered-out background tab overrides the delegate's policy.
	show_tab_window(window, false, Frame{})
	assert !macos.msg_bool(window, 'isVisible')
	assert macos.msg_f64(window, 'alphaValue') == 1
	assert !macos.msg_bool(window, 'ignoresMouseEvents')
	assert !macos.msg_bool_id(delegate, policy, app)
	assert terminate_counts.asked == 0
	// Otherwise the delegate's own policy applies.
	mut state := unsafe { tab_window_state }
	state.hidden = false
	assert macos.msg_bool_id(delegate, policy, app)
	assert terminate_counts.asked == 1
	// Closing a visible tab's window keeps the ordinary termination path.
	macos.msg_void(window, 'close')
	assert !tab_window_state.hidden
}

fn test_joining_tab_launch_stays_out_of_the_dock_until_shown() {
	pool := macos.autorelease_pool_new()
	defer { macos.release(pool) }
	set_policy := method_implementation(application_method('setActivationPolicy:'))
	activate := method_implementation(application_method('activateIgnoringOtherApps:'))
	begin_tab_process_launch()
	begin_tab_process_launch()
	app := ns_app()
	assert !is_nil(app)
	assert macos.msg_i64(app, 'activationPolicy') == activation_policy_accessory
	// Sokol's unconditional launch requests are ignored while the tab starts.
	assert method_implementation(application_method('activateIgnoringOtherApps:')) == voidptr(ignore_activation)
	macos.msg_void_i64(app, 'setActivationPolicy:', activation_policy_regular)
	macos.msg_void_bool(app, 'activateIgnoringOtherApps:', true)
	assert macos.msg_i64(app, 'activationPolicy') == activation_policy_accessory
	window := macos.msg_id_rect_u64_u64_bool(macos.alloc('NSWindow'),
		'initWithContentRect:styleMask:backing:defer:', macos.rect(40, 50, 800, 600),
		ns_window_style_titled, 2, false)
	macos.msg_void_bool(window, 'setReleasedWhenClosed:', false)
	defer { macos.release(window) }
	// Joining restores AppKit; the hidden tab remains an accessory app.
	prepare_tab_window(window)
	assert method_implementation(application_method('setActivationPolicy:')) == set_policy
	assert method_implementation(application_method('activateIgnoringOtherApps:')) == activate
	assert !tab_launch_state.suppressing
	assert macos.msg_i64(app, 'activationPolicy') == activation_policy_accessory
	// Finishing after a join changes nothing.
	finish_tab_process_launch()
	assert macos.msg_i64(app, 'activationPolicy') == activation_policy_accessory
	// A real policy change takes effect again; hiding a tab drops its regular
	// status, so only the shown tab has a Dock and application-switcher entry.
	macos.msg_void_i64(app, 'setActivationPolicy:', activation_policy_regular)
	assert macos.msg_i64(app, 'activationPolicy') == activation_policy_regular
	show_tab_window(window, false, Frame{})
	assert !macos.msg_bool(window, 'isVisible')
	assert macos.msg_i64(app, 'activationPolicy') == activation_policy_accessory
}

fn test_detached_tab_process_launch() {
	pool := macos.autorelease_pool_new()
	defer { macos.release(pool) }
	assert open_tab_window('/usr/bin/true', 'session-path')
	assert !open_tab_window('/nonexistent/vox', 'session-path')
	x, y := pointer_location()
	assert x == x && y == y
	// Without a key or main window there is nothing to measure.
	width, height := key_window_size()
	assert width == 0 && height == 0
}
