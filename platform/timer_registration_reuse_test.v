module platform

#include "@VMODROOT/platform/timer_registration_reuse_test.h"

fn C.libweb_v_idle_timer_pool_size() u32
fn C.libweb_v_idle_timer_pool_has_no_receivers() bool
fn C.libweb_v_clear_idle_timer_pool()
fn C.vox_timer_pool_worker_is_not_pooled() bool

@[heap]
struct NativeTimerReuseObservation {
mut:
	fires int
	first_registration voidptr
}

fn test_cancelled_zero_timer_reuses_only_an_empty_native_registration() {
	$if macos {
		C.libweb_v_clear_idle_timer_pool()
		defer { C.libweb_v_clear_idle_timer_pool() }
		state := &NativeTimerObservation{}
		for _ in 0 .. 64 {
			mut cancelled := Timer.create_single_shot(0, fn () { assert false })
			cancelled.start()
			cancelled.stop()
			assert !cancelled.has_activity_root()
			assert C.libweb_v_idle_timer_pool_has_no_receivers()
			assert C.libweb_v_idle_timer_pool_size() == if retain_native_timer_allocations { u32(0) } else { u32(1) }
		}
		mut delivered := Timer.create_single_shot(0, fn [state] () {
			mut observation := unsafe { &NativeTimerObservation(state) }
			observation.fires++
		})
		delivered.start()
		wait_for_native_timer(fn [state] () bool { return state.fires == 1 })
		pump_native_events(0.002)
		assert state.fires == 1
		assert !delivered.has_activity_root()
		assert C.libweb_v_idle_timer_pool_has_no_receivers()
	}
}

fn test_native_registration_pool_is_bounded_without_retaining_stopped_receivers() {
	$if macos {
		C.libweb_v_clear_idle_timer_pool()
		defer { C.libweb_v_clear_idle_timer_pool() }
		mut timers := []&Timer{}
		for _ in 0 .. 40 {
			mut timer := Timer.create_single_shot(0, fn () { assert false })
			timer.start()
			timers << timer
		}
		for mut timer in timers {
			timer.stop()
			assert !timer.has_activity_root()
		}
		assert C.libweb_v_idle_timer_pool_size() == if retain_native_timer_allocations { u32(0) } else { u32(16) }
		assert C.libweb_v_idle_timer_pool_has_no_receivers()
		pump_native_events(0.002)
	}
}

fn test_zero_timer_restart_from_its_native_callback_has_a_distinct_registration() {
	$if macos {
		C.libweb_v_clear_idle_timer_pool()
		defer { C.libweb_v_clear_idle_timer_pool() }
		state := &NativeTimerReuseObservation{}
		mut timer := Timer.create_single_shot(0, fn () {})
		timer.on_timeout = fn [mut timer, state] () {
			mut observation := unsafe { &NativeTimerReuseObservation(state) }
			observation.fires++
			if observation.fires == 1 {
				assert C.libweb_v_idle_timer_pool_size() == 0
				timer.restart()
				assert timer.native_timer_ != observation.first_registration
				// Nested pumping may deliver the new registration, as it did
				// before pooling. The active carrier itself cannot be recycled.
				pump_native_events(0)
			}
		}
		timer.start()
		mut observation := unsafe { &NativeTimerReuseObservation(state) }
		observation.first_registration = timer.native_timer_
		// The old callback stops its registration before calling the V handler.
		// The second handler can therefore enter on a separately allocated timer.
		wait_for_native_timer(fn [state] () bool { return state.fires >= 2 })
		assert state.fires == 2
		assert !timer.is_active()
		assert !timer.has_activity_root()
		assert C.libweb_v_idle_timer_pool_has_no_receivers()
	}
}

fn test_positive_interval_and_worker_timers_do_not_enter_the_zero_delay_pool() {
	$if macos {
		C.libweb_v_clear_idle_timer_pool()
		defer { C.libweb_v_clear_idle_timer_pool() }
		mut timer := Timer.create_repeating(10, fn () { assert false })
		timer.start()
		timer.restart_with_interval(20)
		timer.stop()
		assert C.libweb_v_idle_timer_pool_size() == 0
		assert C.vox_timer_pool_worker_is_not_pooled()
		assert C.libweb_v_idle_timer_pool_size() == 0
	}
}

fn test_reused_zero_timer_preserves_repeating_delivery_and_dirty_interval_changes() {
	$if macos {
		C.libweb_v_clear_idle_timer_pool()
		defer { C.libweb_v_clear_idle_timer_pool() }
		mut seed := Timer.create_single_shot(0, fn () { assert false })
		seed.start()
		seed.stop()
		state := &NativeTimerObservation{}
		mut timer := Timer.create_repeating(0, fn [state] () {
			mut observation := unsafe { &NativeTimerObservation(state) }
			observation.fires++
		})
		timer.start()
		wait_for_native_timer(fn [state] () bool { return state.fires >= 3 })
		timer.set_interval(5)
		before := state.fires
		wait_for_native_timer(fn [state, before] () bool { return state.fires >= before + 2 })
		timer.stop()
		assert timer.interval() == 5
		assert C.libweb_v_idle_timer_pool_has_no_receivers()
	}
}

fn test_idle_zero_registration_outlives_the_released_document_without_a_receiver() {
	$if macos {
		C.libweb_v_clear_idle_timer_pool()
		defer { C.libweb_v_clear_idle_timer_pool() }
		for delivered in [false, true] {
			mut owner := new_retained_arena('pooled zero timer document')
			mut scope := owner.enter()
			payload := 'owned zero timer payload'.bytes()
			mut timer := Timer.create_single_shot(0, fn [payload] () {
				assert payload.bytestr() == 'owned zero timer payload'
			})
			timer.start()
			scope.finish()
			owner.release()
			if delivered {
				pump_native_events(0.01)
			} else {
				timer.stop()
			}
			// The Timer and its captured payload have already been released.
			assert owner.arena.usage().used == 0
			assert C.libweb_v_idle_timer_pool_has_no_receivers()
			pump_native_events(0.002)
		}
	}
}
