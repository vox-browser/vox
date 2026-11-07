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

// NSApplicationActivationPolicy values. Only a regular application has a Dock
// icon and an application-switcher entry; an accessory one can still show
// windows and be activated.
const activation_policy_regular = i64(0)
const activation_policy_accessory = i64(1)

struct TabLaunchState {
mut:
	suppressing bool
	set_policy  voidptr
	activate    voidptr
}

const tab_launch_state = &TabLaunchState{}

fn ignore_activation_policy(_app voidptr, _selector voidptr, _policy i64) bool {
	return true
}

fn ignore_activation(_app voidptr, _selector voidptr, _flag bool) {}

fn application_method(selector string) voidptr {
	return class_instance_method(lookup_class('NSApplication'), macos.sel(selector))
}

// begin_tab_process_launch starts a tab process that joins an existing group
// as an accessory application. Every tab is its own process, so only the tab
// whose window is shown may appear in the Dock and the application switcher.
// Sokol makes every application regular and activates it before its init
// callback; until prepare_tab_window (or finish_tab_process_launch) both
// requests are ignored, so a starting tab neither registers a Dock icon nor
// takes focus from the selected tab. Call it before the application runs.
pub fn begin_tab_process_launch() {
	mut state := unsafe { tab_launch_state }
	if state.suppressing {
		return
	}
	app := macos.msg_id(macos.get_class('NSApplication'), 'sharedApplication')
	macos.msg_void_i64(app, 'setActivationPolicy:', activation_policy_accessory)
	state.set_policy = method_set_implementation(application_method('setActivationPolicy:'),
		voidptr(ignore_activation_policy))
	state.activate = method_set_implementation(application_method('activateIgnoringOtherApps:'),
		voidptr(ignore_activation))
	state.suppressing = true
}

fn end_tab_process_launch() bool {
	mut state := unsafe { tab_launch_state }
	if !state.suppressing {
		return false
	}
	method_set_implementation(application_method('setActivationPolicy:'), state.set_policy)
	method_set_implementation(application_method('activateIgnoringOtherApps:'), state.activate)
	state.suppressing = false
	return true
}

// finish_tab_process_launch completes a launch that did not become a hidden
// tab (for example when joining its group failed): the process becomes the
// regular, active application Sokol would have made it.
pub fn finish_tab_process_launch() {
	if end_tab_process_launch() {
		app := ns_app()
		macos.msg_void_i64(app, 'setActivationPolicy:', activation_policy_regular)
		macos.msg_void_bool(app, 'activateIgnoringOtherApps:', true)
	}
}

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
	// Sokol's launch-time requests have run; a later show_tab_window makes the
	// process regular and active.
	end_tab_process_launch()
	macos.msg_void_i64(ns_app(), 'setActivationPolicy:', activation_policy_accessory)
	install_tab_window_lifetime_policy(window)
	handle := macos.Id(window)
	macos.msg_void_f64(handle, 'setAlphaValue:', 0)
	macos.msg_void_bool(handle, 'setIgnoresMouseEvents:', true)
}

// close_tab_window closes a tab's window after its process was asked to quit
// (sapp.quit). Sokol otherwise closes it from its next frame, which never
// comes while the window is covered by the tab that replaced it.
pub fn close_tab_window(window voidptr) {
	macos.msg_void1(macos.Id(window), 'performClose:', nil_id())
}

pub fn tab_window_frame(window voidptr) Frame {
	return frame_of(macos.msg_rect(macos.Id(window), 'frame'))
}

// show_tab_window orders a process tab's window in or out. A shown window
// takes `frame` when it has an area, becomes key and activates the app. Only
// a shown tab is a regular application: hidden tabs leave the Dock and the
// application switcher, so a window of ten tabs is a single Vox entry.
pub fn show_tab_window(window voidptr, visible bool, frame Frame) {
	install_tab_window_lifetime_policy(window)
	mut state := unsafe { tab_window_state }
	state.hidden = !visible
	handle := macos.Id(window)
	app := ns_app()
	if !visible {
		macos.msg_void1(handle, 'orderOut:', nil_id())
		macos.msg_void_f64(handle, 'setAlphaValue:', 1)
		macos.msg_void_bool(handle, 'setIgnoresMouseEvents:', false)
		macos.msg_void_i64(app, 'setActivationPolicy:', activation_policy_accessory)
		return
	}
	// Become regular before activating, so the activation also hands this
	// process the menu bar.
	macos.msg_void_i64(app, 'setActivationPolicy:', activation_policy_regular)
	macos.msg_void_f64(handle, 'setAlphaValue:', 1)
	macos.msg_void_bool(handle, 'setIgnoresMouseEvents:', false)
	if frame.width > 0 && frame.height > 0 {
		msg_void_rect_bool(handle, 'setFrame:display:', rect_of(frame), true)
	}
	macos.msg_void1(handle, 'makeKeyAndOrderFront:', nil_id())
	macos.msg_void_bool(app, 'activateIgnoringOtherApps:', true)
	// Commit the ordering now: the caller then tells the previously shown tab
	// to hide its window, which must not happen before this one is on screen.
	macos.msg_void(macos.get_class('CATransaction'), 'flush')
}
