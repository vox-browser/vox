module browserwindow

import macos

type MsgOtherEvent = fn (macos.Id, macos.Sel, u64, macos.Point, u64, f64, i64, macos.Id, i16, i64, i64) macos.Id

type MsgVoidIdBool = fn (macos.Id, macos.Sel, macos.Id, bool)

const ns_event_type_application_defined = u64(15)

fn application_defined_event() macos.Id {
	send := unsafe { MsgOtherEvent(objc_msg_send()) }
	return send(macos.get_class('NSEvent'),
		macos.sel('otherEventWithType:location:modifierFlags:timestamp:windowNumber:context:subtype:data1:data2:'),
		ns_event_type_application_defined, macos.point(0, 0), 0, 0, 0, nil_id(), 1042, 0, 0)
}

fn queued_application_event(app macos.Id) macos.Id {
	return msg_id_u64_id_id_bool(app, 'nextEventMatchingMask:untilDate:inMode:dequeue:',
		u64(1) << ns_event_type_application_defined, macos.msg_id(macos.get_class('NSDate'),
		'distantPast'), framework_string('kCFRunLoopDefaultMode'), false)
}

// AppKit may need more than one pass before a newly posted event can be
// dequeued, so drain with a bounded number of pumps.
fn pump_until_drained(app macos.Id) bool {
	for _ in 0 .. 8 {
		assert pump_pending_events(16)
		if is_nil(queued_application_event(app)) {
			return true
		}
	}
	return false
}

fn post_application_events(app macos.Id, count int) {
	post := unsafe { MsgVoidIdBool(objc_msg_send()) }
	for _ in 0 .. count {
		post(app, macos.sel('postEvent:atStart:'), application_defined_event(), false)
	}
}

fn test_event_pump_requires_an_application_then_dispatches_queued_events() {
	pool := macos.autorelease_pool_new()
	defer { macos.release(pool) }
	// No application object exists yet, and the pump must not create one.
	assert !pump_pending_events(16)
	assert is_nil(ns_app())
	app := macos.msg_id(macos.get_class('NSApplication'), 'sharedApplication')
	assert ns_app() == app
	post_application_events(app, 3)
	assert !is_nil(queued_application_event(app))
	previous := macos.msg_id(macos.get_class('NSGraphicsContext'), 'currentContext')
	assert pump_until_drained(app)
	assert macos.msg_id(macos.get_class('NSGraphicsContext'), 'currentContext') == previous
}

fn test_event_pump_with_no_limit_dispatches_nothing() {
	pool := macos.autorelease_pool_new()
	defer { macos.release(pool) }
	app := macos.msg_id(macos.get_class('NSApplication'), 'sharedApplication')
	post_application_events(app, 2)
	assert pump_pending_events(0)
	assert !is_nil(queued_application_event(app))
	assert pump_until_drained(app)
}
