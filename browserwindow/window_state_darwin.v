module browserwindow

import macos

// AppKit donates every window to Spotlight as a com.apple.window-tab item. The
// CascadeSets SetStoreUpdateService it starts runs in the browser's resource
// coalition and retires about 240M instructions at each launch. Browser tabs
// are UI2-owned, so only the window title is lost. Registering the default in
// the registration domain keeps an explicit
// `defaults write ... NSEnableWindowTabIndexing -bool YES` in charge.
// Call before the first window is created.
pub fn register_window_tab_indexing_default() {
	pool := macos.autorelease_pool_new()
	defer { macos.release(pool) }
	disabled := msg_id_bool(macos.get_class('NSNumber'), 'numberWithBool:', false)
	defaults := macos.msg_id2(macos.get_class('NSDictionary'), 'dictionaryWithObject:forKey:',
		disabled, macos.nsstring('NSEnableWindowTabIndexing'))
	macos.msg_void1(macos.msg_id(macos.get_class('NSUserDefaults'), 'standardUserDefaults'),
		'registerDefaults:', defaults)
}

// snapshot reads a window's frame, minimum size and presentation state.
pub fn snapshot(window voidptr) Snapshot {
	handle := macos.Id(window)
	// NSSize and NSPoint share a layout: two CGFloat fields.
	minimum := macos.msg_point(handle, 'minSize')
	return Snapshot{
		frame:        frame_of(macos.msg_rect(handle, 'frame'))
		min_width:    minimum.x
		min_height:   minimum.y
		zoomed:       macos.msg_bool(handle, 'isZoomed')
		fullscreen:   macos.msg_u64(handle, 'styleMask') & ns_window_style_fullscreen != 0
		miniaturized: macos.msg_bool(handle, 'isMiniaturized')
	}
}

// screen_frames returns the visible frame of every attached screen, primary
// screen first.
pub fn screen_frames() []Frame {
	screens := macos.msg_id(macos.get_class('NSScreen'), 'screens')
	count := int(macos.msg_u64(screens, 'count'))
	mut frames := []Frame{cap: count}
	for i in 0 .. count {
		screen := macos.msg_id_u64(screens, 'objectAtIndex:', u64(i))
		frames << frame_of(macos.msg_rect(screen, 'visibleFrame'))
	}
	return frames
}

// screen_index returns the index in screen_frames of the window's screen,
// or 0 when the window is not on a screen.
pub fn screen_index(window voidptr) int {
	screens := macos.msg_id(macos.get_class('NSScreen'), 'screens')
	index := macos.msg_u64_id(screens, 'indexOfObject:', macos.msg_id(macos.Id(window), 'screen'))
	return if index == ns_not_found { 0 } else { int(index) }
}

pub fn set_frame(window voidptr, frame Frame) {
	msg_void_rect_bool(macos.Id(window), 'setFrame:display:', rect_of(frame), false)
}

pub fn zoom(window voidptr) {
	macos.msg_void1(macos.Id(window), 'zoom:', nil_id())
}

pub fn toggle_fullscreen(window voidptr) {
	macos.msg_void1(macos.Id(window), 'toggleFullScreen:', nil_id())
}

// read_plist_json reads a property-list dictionary and returns it as JSON.
// A missing, invalid or non-JSON-representable file returns none.
pub fn read_plist_json(path string) ?string {
	pool := macos.autorelease_pool_new()
	defer { macos.release(pool) }
	value := macos.msg_id1(macos.get_class('NSDictionary'), 'dictionaryWithContentsOfFile:',
		macos.nsstring(path))
	serialization := macos.get_class('NSJSONSerialization')
	if is_nil(value) || !macos.msg_bool_id(serialization, 'isValidJSONObject:', value) {
		return none
	}
	data := msg_id_id_u64_ptr(serialization, 'dataWithJSONObject:options:error:', value, 0,
		unsafe { nil })
	if is_nil(data) {
		return none
	}
	bytes := &u8(macos.msg_id(data, 'bytes'))
	return unsafe { tos(bytes, int(macos.msg_u64(data, 'length'))).clone() }
}

// write_plist_json writes a JSON object as a property-list dictionary.
pub fn write_plist_json(path string, json string) bool {
	pool := macos.autorelease_pool_new()
	defer { macos.release(pool) }
	data := msg_id_ptr_u64(macos.get_class('NSData'), 'dataWithBytes:length:', json.str,
		u64(json.len))
	value := msg_id_id_u64_ptr(macos.get_class('NSJSONSerialization'),
		'JSONObjectWithData:options:error:', data, 0, unsafe { nil })
	return macos.msg_bool_id(value, 'isKindOfClass:', macos.get_class('NSDictionary'))
		&& macos.msg_bool_id_bool(value, 'writeToFile:atomically:', macos.nsstring(path), true)
}

// The window notifications an observer receives, and the event each reports.
const window_notifications = ['NSWindowDidResizeNotification',
	'NSWindowWillEnterFullScreenNotification', 'NSWindowDidEnterFullScreenNotification',
	'NSWindowWillExitFullScreenNotification', 'NSWindowDidExitFullScreenNotification',
	'NSWindowWillCloseNotification', 'NSWindowDidMoveNotification',
	'NSWindowDidEndLiveResizeNotification', 'NSWindowDidDeminiaturizeNotification']!
const window_notification_events = [event_changed, event_will_enter_fullscreen,
	event_did_enter_fullscreen, event_will_exit_fullscreen, event_did_exit_fullscreen,
	event_closing, event_changed, event_changed, event_changed]!

struct WindowObservation {
mut:
	observer macos.Id
	window   voidptr
	owner    voidptr
	callback WindowEventFn = unsafe { nil }
}

const window_observation = &WindowObservation{}

fn window_observer() macos.Id {
	mut observation := unsafe { window_observation }
	if is_nil(observation.observer) {
		cls := runtime_class('VoxBrowserWindowObserver', [
			RuntimeMethod{ selector: 'voxWindowChanged:', implementation: voidptr(window_changed), types: 'v@:@' },
			RuntimeMethod{ selector: 'voxWindowWillEnterFullScreen:', implementation: voidptr(window_will_enter_fullscreen), types: 'v@:@' },
			RuntimeMethod{ selector: 'voxWindowDidEnterFullScreen:', implementation: voidptr(window_did_enter_fullscreen), types: 'v@:@' },
			RuntimeMethod{ selector: 'voxWindowWillExitFullScreen:', implementation: voidptr(window_will_exit_fullscreen), types: 'v@:@' },
			RuntimeMethod{ selector: 'voxWindowDidExitFullScreen:', implementation: voidptr(window_did_exit_fullscreen), types: 'v@:@' },
			RuntimeMethod{ selector: 'voxWindowClosing:', implementation: voidptr(window_closing), types: 'v@:@' },
		])
		observation.observer = macos.msg_id(cls, 'new')
	}
	return observation.observer
}

fn window_event_selector(kind int) macos.Sel {
	return macos.sel(match kind {
		event_will_enter_fullscreen { 'voxWindowWillEnterFullScreen:' }
		event_did_enter_fullscreen { 'voxWindowDidEnterFullScreen:' }
		event_will_exit_fullscreen { 'voxWindowWillExitFullScreen:' }
		event_did_exit_fullscreen { 'voxWindowDidExitFullScreen:' }
		event_closing { 'voxWindowClosing:' }
		else { 'voxWindowChanged:' }
	})
}

// observe reports the window's resize, move, fullscreen and close
// notifications, and application termination, to callback. It replaces any
// earlier observation.
pub fn observe(window voidptr, owner voidptr, callback WindowEventFn) {
	stop_observing()
	observer := window_observer()
	mut observation := unsafe { window_observation }
	observation.window = window
	observation.owner = owner
	observation.callback = callback
	center := macos.msg_id(macos.get_class('NSNotificationCenter'), 'defaultCenter')
	for i, name in window_notifications {
		macos.msg_void_id_sel_id_id(center, 'addObserver:selector:name:object:', observer,
			window_event_selector(window_notification_events[i]), framework_string(name),
			macos.Id(window))
	}
	macos.msg_void_id_sel_id_id(center, 'addObserver:selector:name:object:', observer,
		window_event_selector(event_closing),
		framework_string('NSApplicationWillTerminateNotification'), ns_app())
}

pub fn stop_observing() {
	mut observation := unsafe { window_observation }
	if !is_nil(observation.observer) {
		center := macos.msg_id(macos.get_class('NSNotificationCenter'), 'defaultCenter')
		macos.msg_void1(center, 'removeObserver:', observation.observer)
	}
	observation.window = unsafe { nil }
	observation.owner = unsafe { nil }
	observation.callback = unsafe { nil }
}

fn deliver_window_event(kind int) {
	observation := window_observation
	if observation.callback == unsafe { nil } || is_nil(observation.window) {
		return
	}
	observation.callback(observation.owner, kind, snapshot(observation.window))
}

fn window_changed(_self voidptr, _cmd voidptr, _note voidptr) {
	deliver_window_event(event_changed)
}

fn window_will_enter_fullscreen(_self voidptr, _cmd voidptr, _note voidptr) {
	deliver_window_event(event_will_enter_fullscreen)
}

fn window_did_enter_fullscreen(_self voidptr, _cmd voidptr, _note voidptr) {
	deliver_window_event(event_did_enter_fullscreen)
}

fn window_will_exit_fullscreen(_self voidptr, _cmd voidptr, _note voidptr) {
	deliver_window_event(event_will_exit_fullscreen)
}

fn window_did_exit_fullscreen(_self voidptr, _cmd voidptr, _note voidptr) {
	deliver_window_event(event_did_exit_fullscreen)
}

fn window_closing(_self voidptr, _cmd voidptr, _note voidptr) {
	deliver_window_event(event_closing)
}
