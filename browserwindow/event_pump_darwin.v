module browserwindow

import macos

// pump_pending_events services AppKit during long document work: it gives
// input posted by other threads a bounded chance to reach AppKit's queue, then
// dispatches up to `limit` queued events and updates windows. It returns false
// off the main thread or before an application exists.
//
// Native input may edit chrome or queue a replacement navigation; the V owner
// guards document input and translated timers while this runs. The current
// graphics context is restored afterwards, since dispatched events may draw.
pub fn pump_pending_events(limit int) bool {
	app := ns_app()
	if !macos.msg_bool(macos.get_class('NSThread'), 'isMainThread') || is_nil(app) {
		return false
	}
	pool := macos.autorelease_pool_new()
	defer { macos.release(pool) }
	graphics := macos.get_class('NSGraphicsContext')
	previous := macos.msg_id(graphics, 'currentContext')
	// NSDefaultRunLoopMode is this same CoreFoundation string.
	mode := framework_string('kCFRunLoopDefaultMode')
	// A zero-duration run-loop pass can leave input posted by another thread in
	// AppKit's source until the entire document operation ends.
	C.CFRunLoopRunInMode(mode, 0.001, true)
	distant_past := macos.msg_id(macos.get_class('NSDate'), 'distantPast')
	for _ in 0 .. limit {
		event := msg_id_u64_id_id_bool(app, 'nextEventMatchingMask:untilDate:inMode:dequeue:',
			ns_event_mask_any, distant_past, mode, true)
		if is_nil(event) {
			break
		}
		macos.msg_void1(app, 'sendEvent:', event)
	}
	macos.msg_void(app, 'updateWindows')
	macos.msg_void1(graphics, 'setCurrentContext:', previous)
	return true
}
