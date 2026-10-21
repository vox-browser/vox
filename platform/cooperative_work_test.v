module platform

import time
import os

@[heap]
struct CooperativeWorkObservation {
mut:
	yields int
	fires  int
}

fn cooperative_work_test_callback(context voidptr) {
	mut state := unsafe { &CooperativeWorkObservation(context) }
	state.yields++
	// A host servicing its run loop must not recursively yield engine work.
	cooperative_work_checkpoint_at(i64(9_000_000_000_000_000_000))
}

fn test_cooperative_work_throttles_yields_and_preserves_the_outer_scope() {
	state := &CooperativeWorkObservation{}
	mut outer := begin_cooperative_work(state, cooperative_work_test_callback)
	defer { outer.finish() }
	deadline := cooperative_work_state_.next_yield_ns
	cooperative_work_checkpoint_at(deadline - 1)
	assert state.yields == 0
	cooperative_work_checkpoint_at(deadline)
	assert state.yields == 1
	mut inner := begin_cooperative_work(state, cooperative_work_test_callback)
	inner.finish()
	cooperative_work_checkpoint_at(deadline + 15_000_000)
	assert state.yields == 1
	cooperative_work_checkpoint_at(deadline + 16_000_000)
	assert state.yields == 2
	outer.finish()
	outer.finish()
	cooperative_work_checkpoint_at(deadline + 32_000_000)
	assert state.yields == 2
	assert cooperative_work_state_ == unsafe { nil }
}

fn test_finished_prealloc_work_reuses_its_record_without_retaining_the_last_target() {
	$if !prealloc { return }
	state := &CooperativeWorkObservation{}
	mut warm := begin_cooperative_work(state, cooperative_work_test_callback)
	identity := voidptr(cooperative_work_state_)
	warm.finish()
	before := thread_arena_usage().used
	for _ in 0 .. 1000 {
		mut scope := begin_cooperative_work(state, cooperative_work_test_callback)
		assert voidptr(cooperative_work_state_) == identity
		assert voidptr(cooperative_work_state_.target) == voidptr(state)
		scope.finish()
		assert cooperative_work_spare_.target == unsafe { nil }
		assert cooperative_work_spare_.callback == unsafe { nil }
	}
	assert thread_arena_usage().used - before < 4096
}

fn test_repeated_cooperative_timer_delivery_reuses_queues_timers_and_closures() {
	$if !prealloc { return }
	if !native_timer_scheduling_available() { return }
	state := &CooperativeWorkObservation{}
	mut timer := Timer.create_single_shot(1000, fn [state] () {
		mut observation := unsafe { &CooperativeWorkObservation(state) }
		observation.fires++
	})
	defer { timer.stop() }
	mut before := i64(0)
	for iteration in 0 .. 129 {
		mut scope := begin_cooperative_work(state, cooperative_work_test_callback)
		timer.restart()
		timer.fire()
		scope.finish()
		deadline := time.sys_mono_now() + time.second
		for state.fires <= iteration && time.sys_mono_now() < deadline { pump_native_events(0.001) }
		assert state.fires == iteration + 1
		if iteration == 0 { before = thread_arena_usage().used }
	}
	assert thread_arena_usage().used - before < 8192
}

fn test_reentrant_cooperative_delivery_keeps_its_active_batch_independent() {
	if !native_timer_scheduling_available() { return }
	state := &CooperativeWorkObservation{}
	mut second := Timer.create_single_shot(1000, fn [state] () {
		mut observation := unsafe { &CooperativeWorkObservation(state) }
		observation.fires++
	})
	mut first := Timer.create_single_shot(1000, fn [state, mut second] () {
		mut observation := unsafe { &CooperativeWorkObservation(state) }
		observation.fires++
		mut nested := begin_cooperative_work(state, cooperative_work_test_callback)
		second.restart()
		second.fire()
		nested.finish()
		assert observation.fires == 1
	})
	defer { first.stop(); second.stop() }
	mut scope := begin_cooperative_work(state, cooperative_work_test_callback)
	first.start()
	first.fire()
	scope.finish()
	deadline := time.sys_mono_now() + time.second
	for state.fires < 2 && time.sys_mono_now() < deadline { pump_native_events(0.001) }
	assert state.fires == 2
}

fn test_native_page_timer_is_deferred_and_coalesced_until_work_completes() {
	if !native_timer_scheduling_available() { return }
	state := &CooperativeWorkObservation{}
	mut timer := Timer.create_single_shot(1, fn [state] () {
		mut observation := unsafe { &CooperativeWorkObservation(state) }
		observation.fires++
	})
	defer { timer.stop() }
	mut scope := begin_cooperative_work(state, cooperative_work_test_callback)
	timer.start()
	pump_native_events(0.02)
	timer.fire()
	timer.fire()
	assert state.fires == 0
	assert timer.is_active() && timer.has_activity_root()
	scope.finish()
	assert state.fires == 0
	deadline := time.sys_mono_now() + time.second
	for state.fires == 0 && time.sys_mono_now() < deadline { pump_native_events(0.01) }
	assert state.fires == 1
	assert !timer.is_active() && !timer.has_activity_root()
}

fn test_stopping_or_restarting_a_deferred_timer_discards_its_old_delivery() {
	if !native_timer_scheduling_available() { return }
	state := &CooperativeWorkObservation{}
	mut timer := Timer.create_single_shot(1000, fn [state] () {
		mut observation := unsafe { &CooperativeWorkObservation(state) }
		observation.fires++
	})
	defer { timer.stop() }
	for restart in [false, true] {
		mut scope := begin_cooperative_work(state, cooperative_work_test_callback)
		timer.restart()
		timer.fire()
		if restart { timer.restart() } else { timer.stop() }
		scope.finish()
		pump_native_events(0.02)
		assert state.fires == 0
	}
	timer.fire()
	assert state.fires == 1
}

$if gcboehm ? {
	struct CooperativeHeapTestPolicy {
	mut:
		value usize
	}
	fn cooperative_heap_test_read(context voidptr) voidptr {
		mut value := unsafe { &CooperativeHeapTestPolicy(context) }
		value.value = C.GC_get_free_space_divisor()
		return unsafe { nil }
	}
	fn cooperative_heap_test_write(context voidptr) voidptr {
		value := unsafe { &CooperativeHeapTestPolicy(context) }
		C.GC_set_free_space_divisor(value.value)
		return unsafe { nil }
	}
	fn cooperative_heap_test_divisor() usize {
		mut value := CooperativeHeapTestPolicy{}
		C.GC_call_with_alloc_lock(cooperative_heap_test_read, &value)
		return value.value
	}
	fn cooperative_heap_test_set_divisor(value usize) {
		policy := CooperativeHeapTestPolicy{ value: value }
		C.GC_call_with_alloc_lock(cooperative_heap_test_write, &policy)
	}
}

fn test_sustained_work_adjusts_collection_without_disabling_gc_and_restores_idle_policy() {
	$if gcboehm ? {
		mut saved := map[string]string{}
		for name in ['GC_INITIAL_HEAP_SIZE', 'GC_MAXIMUM_HEAP_SIZE', 'GC_FREE_SPACE_DIVISOR'] {
			saved[name] = os.getenv(name)
			os.setenv(name, '', true)
		}
		original := cooperative_heap_test_divisor()
		defer {
			cooperative_heap_test_set_divisor(original)
			for name, value in saved { os.setenv(name, value, true) }
		}
		state := &CooperativeWorkObservation{}
		cooperative_heap_test_set_divisor(64)
		mut scope := begin_cooperative_work(state, cooperative_work_test_callback)
		cooperative_work_checkpoint_at(cooperative_work_state_.started_ns + 16_000_000)
		assert cooperative_heap_test_divisor() == 64
		cooperative_work_checkpoint_at(cooperative_work_state_.started_ns + 64_000_000)
		assert cooperative_heap_test_divisor() == 8
		assert gc_is_enabled()
		mut inner := begin_cooperative_work(state, cooperative_work_test_callback)
		inner.finish()
		assert cooperative_heap_test_divisor() == 8
		scope.finish()
		assert cooperative_heap_test_divisor() == 64
		mut changed := begin_cooperative_work(state, cooperative_work_test_callback)
		cooperative_work_checkpoint_at(cooperative_work_state_.started_ns + 64_000_000)
		cooperative_heap_test_set_divisor(16)
		changed.finish()
		assert cooperative_heap_test_divisor() == 16
	}
}

fn test_cooperative_heap_adjustment_honors_every_explicit_collector_override() {
	$if gcboehm ? {
		mut saved := map[string]string{}
		for name in ['GC_INITIAL_HEAP_SIZE', 'GC_MAXIMUM_HEAP_SIZE', 'GC_FREE_SPACE_DIVISOR'] {
			saved[name] = os.getenv(name)
			os.setenv(name, '', true)
		}
		original := cooperative_heap_test_divisor()
		defer {
			cooperative_heap_test_set_divisor(original)
			for name, value in saved { os.setenv(name, value, true) }
		}
		state := &CooperativeWorkObservation{}
		for name, _ in saved {
			os.setenv(name, '8', true)
			cooperative_heap_test_set_divisor(64)
			mut scope := begin_cooperative_work(state, cooperative_work_test_callback)
			cooperative_work_checkpoint_at(cooperative_work_state_.started_ns + 64_000_000)
			assert cooperative_heap_test_divisor() == 64
			scope.finish()
			assert cooperative_heap_test_divisor() == 64
			os.setenv(name, '', true)
		}
	}
}
