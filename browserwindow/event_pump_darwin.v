module browserwindow

import macos

// Long document work pumps AppKit at every cooperative checkpoint. NSApp's
// global and the run-loop mode constant never move once resolved; looking
// them up through dyld each time showed up in scrolled frames.
__global browserwindow_pump_ns_app_slot = voidptr(0)
__global browserwindow_pump_mode = voidptr(0)

fn pump_ns_app() macos.Id {
	if browserwindow_pump_ns_app_slot == unsafe { nil } {
		browserwindow_pump_ns_app_slot = C.dlsym(rtld_default(), c'NSApp')
		if browserwindow_pump_ns_app_slot == unsafe { nil } { return nil_id() }
	}
	return unsafe { *&macos.Id(browserwindow_pump_ns_app_slot) }
}

fn pump_run_loop_mode() macos.Id {
	if browserwindow_pump_mode == unsafe { nil } {
		browserwindow_pump_mode = voidptr(framework_string('kCFRunLoopDefaultMode'))
	}
	return macos.Id(browserwindow_pump_mode)
}

// pump_pending_events services AppKit during long document work: it gives
// input posted by other threads a bounded chance to reach AppKit's queue, then
// dispatches up to `limit` queued events and updates windows. It returns false
// off the main thread or before an application exists.
//
// Native input may edit chrome or queue a replacement navigation; the V owner
// guards document input and translated timers while this runs. The current
// graphics context is restored afterwards, since dispatched events may draw.
pub fn pump_pending_events(limit int) bool {
	app := pump_ns_app()
	if !macos.msg_bool(macos.get_class('NSThread'), 'isMainThread') || is_nil(app) {
		return false
	}
	pool := macos.autorelease_pool_new()
	defer { macos.release(pool) }
	graphics := macos.get_class('NSGraphicsContext')
	previous := macos.msg_id(graphics, 'currentContext')
	// NSDefaultRunLoopMode is this same CoreFoundation string.
	mode := pump_run_loop_mode()
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
