module browserwindow

import macos

// open_tab_window launches `executable --restore-tab session` as a new browser
// process without waiting for it.
pub fn open_tab_window(executable string, session string) bool {
	task := macos.new('NSTask')
	defer { macos.release(task) }
	macos.msg_void1(task, 'setExecutableURL:', macos.msg_id1(macos.get_class('NSURL'),
		'fileURLWithPath:', macos.nsstring(executable)))
	flag := macos.msg_id1(macos.get_class('NSArray'), 'arrayWithObject:',
		macos.nsstring('--restore-tab'))
	macos.msg_void1(task, 'setArguments:', macos.msg_id1(flag, 'arrayByAddingObject:',
		macos.nsstring(session)))
	return macos.msg_bool_id(task, 'launchAndReturnError:', nil_id())
}

// pointer_location returns the mouse position in screen coordinates.
pub fn pointer_location() (f64, f64) {
	location := macos.msg_point(macos.get_class('NSEvent'), 'mouseLocation')
	return location.x, location.y
}

// position_key_window moves the key (or main) window's top-left corner to
// (x, top), orders it front and activates the app.
pub fn position_key_window(x f64, top f64) {
	window := key_or_main_window()
	macos.msg_void_point(window, 'setFrameTopLeftPoint:', macos.point(x, top))
	macos.msg_void1(window, 'makeKeyAndOrderFront:', nil_id())
	macos.msg_void_bool(ns_app(), 'activateIgnoringOtherApps:', true)
}

// key_window_size returns the key (or main) window's outer size.
pub fn key_window_size() (f64, f64) {
	frame := macos.msg_rect(key_or_main_window(), 'frame')
	return frame.width, frame.height
}
