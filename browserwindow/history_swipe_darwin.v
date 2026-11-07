module browserwindow

import macos

// Native event and gesture operations only; classification and navigation
// belong to the V callbacks (browserui swipe policy).

const ns_event_type_scroll_wheel = u64(22)
const ns_event_mask_scroll_wheel = u64(1) << 22
const ns_event_phase_none = u64(0)
const ns_event_phase_began = u64(1)
const ns_event_phase_changed = u64(1) << 2
const ns_event_phase_ended = u64(1) << 3
const ns_event_phase_cancelled = u64(1) << 4
const ns_event_modifier_shift = u64(1) << 17
const ns_event_modifier_control = u64(1) << 18
const ns_event_modifier_option = u64(1) << 19
const ns_event_modifier_command = u64(1) << 20
const ns_event_swipe_tracking_lock_direction = u64(1)
const ns_event_swipe_tracking_clamp_gesture_amount = u64(1) << 1

@[heap]
struct SwipeInstallation {
mut:
	// A zeroing weak reference to the observed window.
	window    voidptr
	owner     voidptr
	monitor   macos.Id
	installed bool
	begin     SwipeBeginFn    = unsafe { nil }
	filter    SwipeFilterFn   = unsafe { nil }
	capture   SwipeCaptureFn  = unsafe { nil }
	progress  SwipeProgressFn = unsafe { nil }
}

// An `NSEvent *(^)(NSEvent *)` local monitor handler.
struct SwipeMonitorBlock {
	isa          voidptr
	flags        i32
	reserved     i32
	invoke       voidptr
	descriptor   voidptr
	installation &SwipeInstallation
}

// A `void (^)(CGFloat, NSEventPhase, BOOL, BOOL *)` tracking handler and the
// gesture it continues.
@[heap]
struct SwipeTrackingBlock {
	isa          voidptr
	flags        i32
	reserved     i32
	invoke       voidptr
	descriptor   voidptr
	installation &SwipeInstallation
	document     voidptr
	generation   u64
	delta        i32
mut:
	finished bool
}

const swipe_monitor_descriptor = &BlockDescriptor{
	size:      u64(sizeof(SwipeMonitorBlock))
	signature: c'@16@?0@8'
}
const swipe_tracking_descriptor = &BlockDescriptor{
	size:      u64(sizeof(SwipeTrackingBlock))
	signature: c'v32@?0d8Q16B24^B28'
}

struct SwipeState {
mut:
	current &SwipeInstallation = unsafe { nil }
	// AppKit may still hold a removed monitor's handler, and calls a tracking
	// handler until it reports completion, even after removal. Monitors are
	// kept (one per installation); finished tracking handlers are dropped.
	monitors []&SwipeMonitorBlock
	tracking []&SwipeTrackingBlock
}

const swipe_state = &SwipeState{}

fn swipe_window(installation &SwipeInstallation) macos.Id {
	return load_weak(&installation.window)
}

fn swipe_phase(phase u64) i32 {
	if phase & ns_event_phase_began != 0 {
		return 1
	}
	if phase & ns_event_phase_changed != 0 {
		return 2
	}
	if phase & ns_event_phase_ended != 0 {
		return 3
	}
	if phase & ns_event_phase_cancelled != 0 {
		return 4
	}
	return if phase == ns_event_phase_none { 0 } else { 5 }
}

fn swipe_modifiers(flags u64) u32 {
	mut modifiers := u32(0)
	if flags & ns_event_modifier_shift != 0 {
		modifiers |= 1
	}
	if flags & ns_event_modifier_control != 0 {
		modifiers |= 2
	}
	if flags & ns_event_modifier_option != 0 {
		modifiers |= 4
	}
	if flags & ns_event_modifier_command != 0 {
		modifiers |= 8
	}
	return modifiers
}

// swipe_deliver returns the event to continue ordinary delivery, or nil when
// the history swipe consumed it.
fn swipe_deliver(installation &SwipeInstallation, event macos.Id, enabled bool) macos.Id {
	window := swipe_window(installation)
	if !installation.installed || macos.msg_u64(event, 'type') != ns_event_type_scroll_wheel
		|| is_nil(window) || macos.msg_id(event, 'window') != window {
		return event
	}
	wheel_x := macos.msg_f64(event, 'scrollingDeltaX')
	wheel_y := macos.msg_f64(event, 'scrollingDeltaY')
	decision := installation.filter(installation.owner, swipe_phase(macos.msg_u64(event, 'phase')),
		i32(macos.msg_u64(event, 'momentumPhase') != ns_event_phase_none),
		i32(macos.msg_bool(event, 'hasPreciseScrollingDeltas')), i32(enabled),
		swipe_modifiers(macos.msg_u64(event, 'modifierFlags')), wheel_x, wheel_y)
	if decision == 0 {
		return event
	}
	if decision == 1 {
		return nil_id()
	}
	content := macos.msg_id(window, 'contentView')
	point := macos.msg_point_point_id(content, 'convertPoint:fromView:', macos.msg_point(event,
		'locationInWindow'), nil_id())
	bounds := macos.msg_rect(content, 'bounds')
	x := point.x - bounds.x
	y := if macos.msg_bool(content, 'isFlipped') {
		point.y - bounds.y
	} else {
		bounds.y + bounds.height - point.y
	}
	delta := i32(if decision < 0 { -1 } else { 1 })
	mut document := unsafe { voidptr(nil) }
	candidate := installation.capture(installation.owner, 0)
	result := installation.begin(installation.owner, delta, x, y, wheel_x, wheel_y, &document)
	if result == 0 {
		return event
	}
	if result != 2 || is_nil(document) || !installation.installed {
		return nil_id()
	}
	generation := installation.capture(installation.owner, candidate)
	if generation == 0 {
		return nil_id()
	}
	handler := track_swipe_handler(installation, document, generation, delta)
	msg_void_u64_f64_f64_id(event, 'trackSwipeEventWithOptions:dampenAmountThresholdMin:max:usingHandler:',
		ns_event_swipe_tracking_lock_direction | ns_event_swipe_tracking_clamp_gesture_amount,
		if delta > 0 { -1.0 } else { 0.0 }, if delta < 0 { 1.0 } else { 0.0 }, macos.Id(handler))
	return nil_id()
}

fn track_swipe_handler(installation &SwipeInstallation, document voidptr, generation u64, delta i32) &SwipeTrackingBlock {
	mut state := unsafe { swipe_state }
	state.tracking = state.tracking.filter(!it.finished)
	handler := &SwipeTrackingBlock{
		isa:          global_block_isa()
		flags:        global_block_flags()
		invoke:       voidptr(swipe_tracking_invoke)
		descriptor:   voidptr(swipe_tracking_descriptor)
		installation: installation
		document:     document
		generation:   generation
		delta:        delta
	}
	state.tracking << handler
	return handler
}

fn swipe_monitor_invoke(block &SwipeMonitorBlock, event macos.Id) macos.Id {
	return swipe_deliver(block.installation, event, macos.msg_bool(macos.get_class('NSEvent'),
		'isSwipeTrackingFromScrollEventsEnabled'))
}

fn swipe_tracking_invoke(block &SwipeTrackingBlock, amount f64, phase u64, complete bool, stop &bool) {
	mut handler := unsafe { block }
	installation := handler.installation
	if !installation.installed || is_nil(swipe_window(installation)) {
		handler.finished = true
		unsafe {
			*stop = true
		}
		return
	}
	finish := installation.progress(installation.owner, handler.document, handler.generation,
		amount, swipe_phase(phase), i32(complete), handler.delta) != 0
	handler.finished = finish || complete
	unsafe {
		*stop = finish
	}
}

// install_history_swipe routes the window's horizontal scroll gestures to the
// history swipe callbacks, replacing any earlier installation.
pub fn install_history_swipe(window voidptr, owner voidptr, begin SwipeBeginFn, filter SwipeFilterFn, capture SwipeCaptureFn, progress SwipeProgressFn) {
	remove_history_swipe()
	if is_nil(window) || is_nil(owner) {
		return
	}
	mut installation := &SwipeInstallation{
		owner:     owner
		installed: true
		begin:     begin
		filter:    filter
		capture:   capture
		progress:  progress
	}
	store_weak(&installation.window, window)
	monitor := &SwipeMonitorBlock{
		isa:          global_block_isa()
		flags:        global_block_flags()
		invoke:       voidptr(swipe_monitor_invoke)
		descriptor:   voidptr(swipe_monitor_descriptor)
		installation: installation
	}
	mut state := unsafe { swipe_state }
	state.monitors << monitor
	installation.monitor = macos.retain(macos.msg_id_u64_id(macos.get_class('NSEvent'),
		'addLocalMonitorForEventsMatchingMask:handler:', ns_event_mask_scroll_wheel, macos.Id(monitor)))
	state.current = installation
}

pub fn remove_history_swipe() {
	mut state := unsafe { swipe_state }
	mut installation := state.current
	if voidptr(installation) == unsafe { nil } {
		return
	}
	installation.installed = false
	if !is_nil(installation.monitor) {
		macos.msg_void1(macos.get_class('NSEvent'), 'removeMonitor:', installation.monitor)
		macos.release(installation.monitor)
		installation.monitor = nil_id()
	}
	store_weak(&installation.window, unsafe { nil })
	state.current = unsafe { nil }
}
