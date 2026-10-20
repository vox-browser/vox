module platform

import time
import os

pub type CooperativeWorkCallback = fn (voidptr)

struct CooperativeWorkState {
	callback CooperativeWorkCallback
	target   voidptr
mut:
	next_yield_ns           i64
	started_ns              i64
	delivering              bool
	deferred_timers         []DeferredWorkTimer
	heap_adjustment_allowed bool
	heap_policy_changed     bool
	previous_heap_divisor   usize
	applied_heap_divisor    usize
}

struct DeferredWorkTimer {
	timer      &Timer
	generation u64
	owner &RetainedArena = unsafe { nil }
}

__global cooperative_work_state_ &CooperativeWorkState

pub struct CooperativeWorkScope {
mut:
	state &CooperativeWorkState = unsafe { nil }
}

// A browser may service native chrome during long synchronous engine work.
// Page timers retain ordinary run-to-completion ordering until the scope ends.
pub fn begin_cooperative_work(target voidptr, callback CooperativeWorkCallback) CooperativeWorkScope {
	$if macos || linux {
		if !C.libweb_v_is_main_thread() { return CooperativeWorkScope{} }
	}
	if cooperative_work_state_ != unsafe { nil } { return CooperativeWorkScope{} }
	persistent := enter_persistent()
	defer { leave_persistent(persistent) }
	now := time.sys_mono_now()
	mut heap_adjustment_allowed := false
	$if gcboehm ? {
		heap_adjustment_allowed = os.getenv('GC_INITIAL_HEAP_SIZE') == ''
			&& os.getenv('GC_MAXIMUM_HEAP_SIZE') == '' && os.getenv('GC_FREE_SPACE_DIVISOR') == ''
	}
	state := &CooperativeWorkState{
		target:                  target
		callback:                callback
		started_ns:              now
		next_yield_ns:           now + 16_000_000
		heap_adjustment_allowed: heap_adjustment_allowed
	}
	cooperative_work_state_ = state
	return CooperativeWorkScope{ state: state }
}

pub fn cooperative_work_checkpoint() {
	$if macos || linux {
		if !C.libweb_v_is_main_thread() { return }
	}
	if cooperative_work_state_ == unsafe { nil } { return }
	cooperative_work_checkpoint_at(time.sys_mono_now())
}

fn cooperative_work_checkpoint_at(now_ns i64) {
	mut state := cooperative_work_state_
	if state == unsafe { nil } || state.delivering || now_ns < state.next_yield_ns { return }
	$if gcboehm ? {
		// A tight idle policy can repeatedly trace the same growing DOM/CSS
		// graph. Give sustained work room to advance without reserving a heap
		// or disabling collection. Short frames retain the idle policy.
		if state.heap_adjustment_allowed && !state.heap_policy_changed
			&& now_ns - state.started_ns >= 64_000_000 {
			C.GC_call_with_alloc_lock(adjust_cooperative_heap_locked, state)
		}
	}
	state.next_yield_ns = now_ns + 16_000_000
	state.delivering = true
	defer { state.delivering = false }
	state.callback(state.target)
}

$if gcboehm ? {
	fn adjust_cooperative_heap_locked(context voidptr) voidptr {
		mut state := unsafe { &CooperativeWorkState(context) }
		previous := C.GC_get_free_space_divisor()
		minimum := browser_activity_heap_minimum_divisor_locked()
		divisor := if minimum > 8 { minimum } else { usize(8) }
		if previous > divisor {
			state.previous_heap_divisor = previous
			state.applied_heap_divisor = divisor
			state.heap_policy_changed = true
			C.GC_set_free_space_divisor(divisor)
		}
		return unsafe { nil }
	}

	fn restore_cooperative_heap_locked(context voidptr) voidptr {
		state := unsafe { &CooperativeWorkState(context) }
		if C.GC_get_free_space_divisor() == state.applied_heap_divisor {
			C.GC_set_free_space_divisor(state.previous_heap_divisor)
		}
		return unsafe { nil }
	}
}

fn defer_timer_during_cooperative_work(timer &Timer) bool {
	$if macos || linux {
		if !C.libweb_v_is_main_thread() { return false }
	}
	mut state := cooperative_work_state_
	if state == unsafe { nil } { return false }
	if !state.deferred_timers.any(voidptr(it.timer) == voidptr(timer) && it.generation == timer.registration_generation_) {
		mut owner := timer.allocation_owner_
		if owner != unsafe { nil } { owner.retain() }
		persistent := enter_persistent()
		state.deferred_timers << DeferredWorkTimer{ timer: timer, generation: timer.registration_generation_, owner: owner }
		leave_persistent(persistent)
	}
	return true
}

pub fn (mut scope CooperativeWorkScope) finish() {
	state := scope.state
	if state == unsafe { nil } { return }
	scope.state = unsafe { nil }
	$if gcboehm ? {
		if state.heap_policy_changed {
			C.GC_call_with_alloc_lock(restore_cooperative_heap_locked, state)
		}
	}
	cooperative_work_state_ = unsafe { nil }
	if state.deferred_timers.len > 0 {
		persistent := enter_persistent()
		defer { leave_persistent(persistent) }
		pending := state.deferred_timers.clone()
		mut delivery := Timer.create_single_shot(0, fn [pending] () {
			for item in pending {
				mut timer := item.timer
				if timer.registration_generation_ == item.generation { timer.fire() }
				mut owner := item.owner
				if owner != unsafe { nil } { owner.release() }
			}
		})
		delivery.start()
	}
}
