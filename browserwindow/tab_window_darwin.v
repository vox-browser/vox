module browserwindow

import macos

type TerminatePolicyFn = fn (delegate voidptr, selector voidptr, app voidptr) bool

struct TabWindowState {
mut:
	hidden             bool
	installed          bool
	original_terminate voidptr
	close_observer     macos.Id
}

const tab_window_state = &TabWindowState{}

// AppKit also asks this policy after orderOut:. A background tab still owns a
// live document and must not shut down its whole process group.
fn tab_terminate_after_last_window(delegate voidptr, selector voidptr, app voidptr) bool {
	state := tab_window_state
	if state.hidden {
		return false
	}
	if is_nil(state.original_terminate) {
		return false
	}
	original := unsafe { TerminatePolicyFn(state.original_terminate) }
	return original(delegate, selector, app)
}

// An explicit close (including sapp_quit()) keeps the normal policy, even when
// the document's window was previously ordered out. A window already ordered
// out cannot trigger another last-visible-window transition, so finish an
// explicit background-tab close here.
fn tab_window_will_close(_self voidptr, _cmd voidptr, _note voidptr) {
	mut state := unsafe { tab_window_state }
	was_hidden := state.hidden
	state.hidden = false
	if was_hidden {
		dispatch_to_main_queue(terminate_application)
	}
}

fn terminate_application(_context voidptr) {
	macos.msg_void1(ns_app(), 'terminate:', nil_id())
}

fn install_tab_window_lifetime_policy(window voidptr) {
	mut state := unsafe { tab_window_state }
	delegate := macos.msg_id(ns_app(), 'delegate')
	if state.installed || is_nil(delegate) {
		return
	}
	state.installed = true
	cls := macos.msg_id(delegate, 'class')
	selector := macos.sel('applicationShouldTerminateAfterLastWindowClosed:')
	method := class_instance_method(cls, selector)
	state.original_terminate = if is_nil(method) {
		unsafe { nil }
	} else {
		method_implementation(method)
	}
	if !class_add_method(cls, selector, voidptr(tab_terminate_after_last_window), c'B@:@') {
		method_set_implementation(class_instance_method(cls, selector), voidptr(tab_terminate_after_last_window))
	}
	observer_class := runtime_class('VoxTabWindowCloseObserver', [
		RuntimeMethod{
			selector:       'voxTabWindowWillClose:'
			implementation: voidptr(tab_window_will_close)
			types:          'v@:@'
		},
	])
	// The notification center does not retain its observers; this one lives
	// for the rest of the process.
	state.close_observer = macos.msg_id(observer_class, 'new')
	center := macos.msg_id(macos.get_class('NSNotificationCenter'), 'defaultCenter')
	macos.msg_void_id_sel_id_id(center, 'addObserver:selector:name:object:', state.close_observer,
		macos.sel('voxTabWindowWillClose:'), framework_string('NSWindowWillCloseNotification'),
		macos.Id(window))
}

// prepare_tab_window keeps a joining tab's window invisible and inert until
// the tab group shows it.
pub fn prepare_tab_window(window voidptr) {
	install_tab_window_lifetime_policy(window)
	handle := macos.Id(window)
	macos.msg_void_f64(handle, 'setAlphaValue:', 0)
	macos.msg_void_bool(handle, 'setIgnoresMouseEvents:', true)
}

pub fn tab_window_frame(window voidptr) Frame {
	return frame_of(macos.msg_rect(macos.Id(window), 'frame'))
}

// show_tab_window orders a process tab's window in or out. A shown window
// takes `frame` when it has an area, becomes key and activates the app.
pub fn show_tab_window(window voidptr, visible bool, frame Frame) {
	install_tab_window_lifetime_policy(window)
	mut state := unsafe { tab_window_state }
	state.hidden = !visible
	handle := macos.Id(window)
	if !visible {
		macos.msg_void1(handle, 'orderOut:', nil_id())
		macos.msg_void_f64(handle, 'setAlphaValue:', 1)
		macos.msg_void_bool(handle, 'setIgnoresMouseEvents:', false)
		return
	}
	macos.msg_void_f64(handle, 'setAlphaValue:', 1)
	macos.msg_void_bool(handle, 'setIgnoresMouseEvents:', false)
	if frame.width > 0 && frame.height > 0 {
		msg_void_rect_bool(handle, 'setFrame:display:', rect_of(frame), true)
	}
	macos.msg_void1(handle, 'makeKeyAndOrderFront:', nil_id())
	macos.msg_void_bool(ns_app(), 'activateIgnoringOtherApps:', true)
}
