module browserwindow

import macos

// AppKit supplies gesture progress asynchronously. Keep that boundary explicit
// so cancellation, reversal and callbacks after teardown are deterministic.
// The swipe policy itself is tested in browserui/swipe_test.v.

struct FakeScrollEvent {
mut:
	window   macos.Id
	phase    u64
	delta_x  f64
	delta_y  f64
	location macos.Point
	handler  voidptr
	options  u64
	minimum  f64
	maximum  f64
}

const fake_scroll_event = &FakeScrollEvent{}

fn fake_event_window(_self voidptr, _cmd voidptr) macos.Id {
	return fake_scroll_event.window
}

fn fake_event_type(_self voidptr, _cmd voidptr) u64 {
	return ns_event_type_scroll_wheel
}

fn fake_event_phase(_self voidptr, _cmd voidptr) u64 {
	return fake_scroll_event.phase
}

fn fake_event_no_phase(_self voidptr, _cmd voidptr) u64 {
	return ns_event_phase_none
}

fn fake_event_precise(_self voidptr, _cmd voidptr) bool {
	return true
}

fn fake_event_delta_x(_self voidptr, _cmd voidptr) f64 {
	return fake_scroll_event.delta_x
}

fn fake_event_delta_y(_self voidptr, _cmd voidptr) f64 {
	return fake_scroll_event.delta_y
}

fn fake_event_location(_self voidptr, _cmd voidptr) macos.Point {
	return fake_scroll_event.location
}

fn fake_event_track(_self voidptr, _cmd voidptr, options u64, minimum f64, maximum f64, handler voidptr) {
	mut event := unsafe { fake_scroll_event }
	event.options = options
	event.minimum = minimum
	event.maximum = maximum
	event.handler = handler
}

fn fake_scroll_event_object(window macos.Id, delta_x f64, delta_y f64, phase u64) macos.Id {
	cls := runtime_class('VoxHistorySwipeTestEvent', [
		RuntimeMethod{ selector: 'window', implementation: voidptr(fake_event_window), types: '@@:' },
		RuntimeMethod{ selector: 'type', implementation: voidptr(fake_event_type), types: 'Q@:' },
		RuntimeMethod{ selector: 'phase', implementation: voidptr(fake_event_phase), types: 'Q@:' },
		RuntimeMethod{ selector: 'momentumPhase', implementation: voidptr(fake_event_no_phase), types: 'Q@:' },
		RuntimeMethod{ selector: 'modifierFlags', implementation: voidptr(fake_event_no_phase), types: 'Q@:' },
		RuntimeMethod{ selector: 'hasPreciseScrollingDeltas', implementation: voidptr(fake_event_precise), types: 'B@:' },
		RuntimeMethod{ selector: 'scrollingDeltaX', implementation: voidptr(fake_event_delta_x), types: 'd@:' },
		RuntimeMethod{ selector: 'scrollingDeltaY', implementation: voidptr(fake_event_delta_y), types: 'd@:' },
		RuntimeMethod{ selector: 'locationInWindow', implementation: voidptr(fake_event_location), types: '{CGPoint=dd}@:' },
		RuntimeMethod{ selector: 'trackSwipeEventWithOptions:dampenAmountThresholdMin:max:usingHandler:', implementation: voidptr(fake_event_track), types: 'v@:Qdd@?' },
	])
	mut event := unsafe { fake_scroll_event }
	event.window = window
	event.delta_x = delta_x
	event.delta_y = delta_y
	event.phase = phase
	event.location = macos.point(100, 350)
	event.handler = unsafe { nil }
	return macos.msg_id(cls, 'new')
}

struct SwipeObservation {
mut:
	begins     int
	commits    int
	phases     int
	delta      i32
	x          f64
	y          f64
	result     i32
	decision   i32
	generation u64
}

struct DocumentToken {
	value int
}

const swipe_document = &DocumentToken{}

fn observed_begin(owner voidptr, delta i32, x f64, y f64, wheel_x f64, wheel_y f64, document &voidptr) i32 {
	mut observation := unsafe { &SwipeObservation(owner) }
	assert wheel_x == 12 && wheel_y == 0
	observation.begins++
	observation.delta = delta
	observation.x = x
	observation.y = y
	unsafe {
		*document = voidptr(swipe_document)
	}
	return observation.result
}

fn observed_filter(owner voidptr, phase i32, momentum i32, precise i32, enabled i32, modifiers u32, x f64, y f64) i32 {
	mut observation := unsafe { &SwipeObservation(owner) }
	assert phase == 1 && momentum == 0 && precise == 1 && enabled == 1 && modifiers == 0
	assert x == 12 && y == 0
	observation.phases++
	return observation.decision
}

fn observed_capture(owner voidptr, expected u64) u64 {
	assert expected == 0 || expected == 42
	return unsafe { &SwipeObservation(owner) }.generation
}

fn observed_progress(owner voidptr, document voidptr, generation u64, amount f64, phase i32, complete i32, delta i32) i32 {
	mut observation := unsafe { &SwipeObservation(owner) }
	assert document == voidptr(swipe_document) && generation == 42 && amount == 1
	assert phase == 3 && complete == 1 && delta == -1
	observation.commits++
	return 1
}

fn test_swipe_phase_and_modifier_normalization() {
	assert swipe_phase(ns_event_phase_none) == 0
	assert swipe_phase(ns_event_phase_began) == 1
	assert swipe_phase(ns_event_phase_changed) == 2
	assert swipe_phase(ns_event_phase_ended) == 3
	assert swipe_phase(ns_event_phase_cancelled) == 4
	assert swipe_phase(u64(1) << 5) == 5
	assert swipe_modifiers(0) == 0
	assert swipe_modifiers(ns_event_modifier_shift | ns_event_modifier_command) == 9
	assert swipe_modifiers(ns_event_modifier_control | ns_event_modifier_option) == 6
}

fn test_history_swipe_routing_tracking_and_teardown() {
	pool := macos.autorelease_pool_new()
	defer { macos.release(pool) }
	macos.msg_id(macos.get_class('NSApplication'), 'sharedApplication')
	window := macos.msg_id_rect_u64_u64_bool(macos.alloc('NSWindow'),
		'initWithContentRect:styleMask:backing:defer:', macos.rect(0, 0, 800, 600), 0, 2, false)
	macos.msg_void_bool(window, 'setReleasedWhenClosed:', false)
	defer { macos.msg_void(window, 'close') }
	mut observation := &SwipeObservation{
		result:     2
		decision:   -2
		generation: 42
	}
	install_history_swipe(window, observation, observed_begin, observed_filter, observed_capture,
		observed_progress)
	installation := swipe_state.current
	assert voidptr(installation) != unsafe { nil }
	assert installation.installed && !is_nil(installation.monitor)
	event := fake_scroll_event_object(window, 12, 0, ns_event_phase_began)
	defer { macos.release(event) }
	assert is_nil(swipe_deliver(installation, event, true))
	assert observation.begins == 1 && observation.phases == 1 && observation.delta == -1
	assert observation.x == 100 && observation.y == 250
	handler := unsafe { &SwipeTrackingBlock(fake_scroll_event.handler) }
	assert voidptr(handler) != unsafe { nil }
	assert fake_scroll_event.options == ns_event_swipe_tracking_lock_direction | ns_event_swipe_tracking_clamp_gesture_amount
	assert fake_scroll_event.minimum == 0 && fake_scroll_event.maximum == 1
	mut stop := false
	swipe_tracking_invoke(handler, 1, ns_event_phase_ended, true, &stop)
	assert stop && observation.commits == 1
	remove_history_swipe()
	assert !installation.installed && is_nil(installation.monitor)
	assert voidptr(swipe_state.current) == unsafe { nil }
	// AppKit can still report progress after teardown.
	stop = false
	swipe_tracking_invoke(handler, 1, ns_event_phase_ended, true, &stop)
	assert stop && observation.commits == 1
	assert swipe_deliver(installation, event, true) == event
	remove_history_swipe()
}

fn test_unconsumed_and_ordinary_wheel_events_continue() {
	pool := macos.autorelease_pool_new()
	defer { macos.release(pool) }
	macos.msg_id(macos.get_class('NSApplication'), 'sharedApplication')
	window := macos.msg_id_rect_u64_u64_bool(macos.alloc('NSWindow'),
		'initWithContentRect:styleMask:backing:defer:', macos.rect(0, 0, 800, 600), 0, 2, false)
	macos.msg_void_bool(window, 'setReleasedWhenClosed:', false)
	defer { macos.msg_void(window, 'close') }
	mut observation := &SwipeObservation{
		result:     0
		decision:   0
		generation: 42
	}
	install_history_swipe(window, observation, observed_begin, observed_filter, observed_capture,
		observed_progress)
	defer { remove_history_swipe() }
	event := fake_scroll_event_object(window, 12, 0, ns_event_phase_began)
	defer { macos.release(event) }
	// The filter leaves ordinary scrolling with the page.
	assert swipe_deliver(swipe_state.current, event, true) == event
	assert observation.begins == 0 && observation.phases == 1
	// The filter consumes the event without starting a gesture.
	observation.decision = 1
	assert is_nil(swipe_deliver(swipe_state.current, event, true))
	assert observation.begins == 0
	// A rejected begin returns the event to ordinary delivery.
	observation.decision = 2
	assert swipe_deliver(swipe_state.current, event, true) == event
	assert observation.begins == 1 && observation.delta == 1
	assert is_nil(fake_scroll_event.handler)
	// Another window's events are not inspected.
	mut other := unsafe { fake_scroll_event }
	other.window = nil_id()
	assert swipe_deliver(swipe_state.current, event, true) == event
	assert observation.phases == 3
}
