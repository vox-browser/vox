module browserwindow

import macos
import os

// Geometry and transition policy live in browserui/window_test.v. This checks
// the native snapshot, notification lifetime and plist conversion.

struct WindowOperations {
mut:
	zooms       int
	fullscreens int
	events      int
	last_kind   int
}

const window_operations = &WindowOperations{}

fn counting_zoom(_self voidptr, _cmd voidptr, _sender voidptr) {
	mut operations := unsafe { window_operations }
	operations.zooms++
}

fn counting_toggle_fullscreen(_self voidptr, _cmd voidptr, _sender voidptr) {
	mut operations := unsafe { window_operations }
	operations.fullscreens++
}

fn operation_test_window() macos.Id {
	name := 'VoxWindowOperationTest'
	mut cls := macos.Id(lookup_class(name))
	if is_nil(cls) {
		cls = macos.allocate_class_pair(macos.get_class('NSWindow'), name)
		macos.add_method(cls, 'zoom:', voidptr(counting_zoom), 'v@:@')
		macos.add_method(cls, 'toggleFullScreen:', voidptr(counting_toggle_fullscreen), 'v@:@')
		macos.register_class_pair(cls)
	}
	window := macos.msg_id_rect_u64_u64_bool(macos.msg_id(cls, 'alloc'),
		'initWithContentRect:styleMask:backing:defer:', macos.rect(0, 0, 800, 600),
		ns_window_style_titled | ns_window_style_closable | ns_window_style_resizable, 2, false)
	macos.msg_void_bool(window, 'setReleasedWhenClosed:', false)
	return window
}

fn record_window_event(owner voidptr, kind int, snapshot Snapshot) {
	assert owner == voidptr(window_operations)
	assert kind >= event_changed && kind <= event_closing
	assert snapshot.frame.width > 0 && snapshot.frame.height > 0
	mut operations := unsafe { window_operations }
	operations.events++
	operations.last_kind = kind
}

fn test_window_tab_indexing_default_uses_the_registration_domain() {
	pool := macos.autorelease_pool_new()
	defer { macos.release(pool) }
	defaults := macos.msg_id(macos.get_class('NSUserDefaults'), 'standardUserDefaults')
	key := macos.nsstring('NSEnableWindowTabIndexing')
	assert is_nil(macos.msg_id1(defaults, 'objectForKey:', key))
	register_window_tab_indexing_default()
	registered := macos.msg_id1(macos.msg_id1(defaults, 'volatileDomainForName:',
		macos.nsstring('NSRegistrationDomain')), 'objectForKey:', key)
	assert !is_nil(registered) && !macos.msg_bool(registered, 'boolValue')
	assert !is_nil(macos.msg_id1(defaults, 'objectForKey:', key))
	assert !macos.msg_bool_id(defaults, 'boolForKey:', key)
	// An explicit value (here the launch-argument domain) still enables indexing.
	argument_domain := macos.nsstring('NSArgumentDomain')
	arguments := macos.msg_id1(defaults, 'volatileDomainForName:', argument_domain)
	enabled := macos.msg_id(arguments, 'mutableCopy')
	macos.msg_void2(enabled, 'setObject:forKey:', msg_id_bool(macos.get_class('NSNumber'),
		'numberWithBool:', true), key)
	macos.msg_void2(defaults, 'setVolatileDomain:forName:', enabled, argument_domain)
	assert macos.msg_bool_id(defaults, 'boolForKey:', key)
	macos.msg_void2(defaults, 'setVolatileDomain:forName:', arguments, argument_domain)
	macos.release(enabled)
}

fn test_window_operations_snapshot_and_notifications() {
	pool := macos.autorelease_pool_new()
	defer { macos.release(pool) }
	macos.msg_id(macos.get_class('NSApplication'), 'sharedApplication')
	window := operation_test_window()
	defer { macos.msg_void(window, 'close') }
	assert screen_frames().len > 0
	assert screen_index(window) >= 0
	zoom(window)
	toggle_fullscreen(window)
	assert window_operations.zooms == 1 && window_operations.fullscreens == 1
	set_frame(window, Frame{ x: 100, y: 100, width: 820, height: 640 })
	current := snapshot(window)
	assert current.frame == Frame{ x: 100, y: 100, width: 820, height: 640 }
	assert !current.fullscreen && !current.miniaturized
	observe(window, voidptr(window_operations), record_window_event)
	center := macos.msg_id(macos.get_class('NSNotificationCenter'), 'defaultCenter')
	macos.msg_void2(center, 'postNotificationName:object:',
		framework_string('NSWindowDidMoveNotification'), window)
	assert window_operations.events == 1 && window_operations.last_kind == event_changed
	macos.msg_void2(center, 'postNotificationName:object:',
		framework_string('NSWindowWillEnterFullScreenNotification'), window)
	assert window_operations.events == 2
		&& window_operations.last_kind == event_will_enter_fullscreen
	// Another window's notifications are not reported.
	other := operation_test_window()
	defer { macos.msg_void(other, 'close') }
	macos.msg_void2(center, 'postNotificationName:object:',
		framework_string('NSWindowDidMoveNotification'), other)
	assert window_operations.events == 2
	stop_observing()
	macos.msg_void2(center, 'postNotificationName:object:',
		framework_string('NSWindowDidMoveNotification'), window)
	assert window_operations.events == 2
}

fn test_plist_json_round_trip_and_invalid_files() {
	path := os.join_path(os.vtmp_dir(), 'browserwindow-${os.getpid()}.plist')
	defer { os.rm(path) or {} }
	json := '{"version":1,"normalFrame":"{{100, 100}, {820, 640}}","maximized":false,"fullscreen":false}'
	assert write_plist_json(path, json)
	loaded := read_plist_json(path) or { panic('the plist was not read') }
	assert loaded.contains('"normalFrame":"{{100, 100}, {820, 640}}"')
	assert loaded.contains('"version":1')
	assert !write_plist_json(path, '[1, 2]')
	os.write_file(path, 'invalid plist') or { panic(err) }
	assert (read_plist_json(path) or { 'none' }) == 'none'
	assert (read_plist_json(os.join_path(path, 'missing')) or { 'none' }) == 'none'
}
