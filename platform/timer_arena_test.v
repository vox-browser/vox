module platform

struct ArenaTimerObservation {
mut:
	fired bool
}

struct NestedTimerRetirementOrder {
mut:
	values [3]int
}

fn test_nested_timer_delivery_finishes_after_callbacks_retire_both_allocation_owners() {
	mut order := &NestedTimerRetirementOrder{}
	mut inner_owner := new_retained_arena('nested inner timer')
	mut inner_scope := inner_owner.enter()
	inner_payload := 'inner payload'.bytes()
	mut inner := Timer.create_single_shot(1000, fn [inner_owner, inner_payload, order] () {
		mut owner := unsafe { &RetainedArena(inner_owner) }
		owner.release()
		assert inner_payload.bytestr() == 'inner payload'
		mut observed := unsafe { &NestedTimerRetirementOrder(order) }
		observed.values[1] = 2
	})
	inner_scope.finish()
	inner.start()
	mut outer_owner := new_retained_arena('nested outer timer')
	mut outer_scope := outer_owner.enter()
	outer_payload := 'outer payload'.bytes()
	mut outer := Timer.create_single_shot(1000, fn [outer_owner, outer_payload, inner, order] () {
		mut owner := unsafe { &RetainedArena(outer_owner) }
		owner.release()
		mut observed := unsafe { &NestedTimerRetirementOrder(order) }
		observed.values[0] = 1
		mut child := unsafe { &Timer(inner) }
		child.fire()
		assert outer_payload.bytestr() == 'outer payload'
		observed.values[2] = 3
	})
	outer_scope.finish()
	outer.start()
	outer.fire()
	assert order.values == [1, 2, 3]!
	assert inner_owner.arena.usage().used == 0
	assert outer_owner.arena.usage().used == 0
}

fn test_active_timer_keeps_its_retired_document_alive_through_callback_cleanup() {
	mut owner := new_retained_arena('timer document')
	observation := &ArenaTimerObservation{}
	mut scope := owner.enter()
	payload := 'timer payload'.bytes()
	mut timer := Timer.create_single_shot(1000, fn [payload, observation] () {
		assert payload.bytestr() == 'timer payload'
		mut result := unsafe { &ArenaTimerObservation(observation) }
		result.fired = true
	})
	timer.start()
	scope.finish()
	owner.release()
	$if prealloc { assert owner.arena.usage().used > 0 }
	timer.fire()
	assert observation.fired
	assert owner.arena.usage().used == 0
}

fn test_stopped_deferred_timer_remains_readable_until_cooperative_delivery() {
	mut owner := new_retained_arena('deferred timer document')
	mut scope := owner.enter()
	mut timer := Timer.create_single_shot(1000, fn () { assert false })
	timer.start()
	mut work := begin_cooperative_work(unsafe { nil }, fn (_ voidptr) {})
	timer.fire()
	timer.stop()
	scope.finish()
	owner.release()
	$if prealloc { assert owner.arena.usage().used > 0 }
	work.finish()
	pump_native_events(0.01)
	assert owner.arena.usage().used == 0
}

fn test_restarting_a_timer_transfers_its_last_activity_lease() {
	mut owner := new_retained_arena('restarted timer document')
	mut scope := owner.enter()
	mut timer := Timer.create_repeating(1000, fn () {})
	timer.start()
	scope.finish()
	owner.release()
	timer.restart_with_interval(2000)
	assert timer.is_active() && timer.interval() == 2000
	timer.stop()
	assert owner.arena.usage().used == 0
}

fn test_process_timer_created_during_document_work_does_not_retain_that_document() {
	mut owner := new_retained_arena('persistent timer initialization')
	observation := &ArenaTimerObservation{}
	owner.add_cleanup(fn [observation] () {
		mut result := unsafe { &ArenaTimerObservation(observation) }
		result.fired = true
	})
	mut scope := owner.enter()
	persistent := enter_persistent()
	mut timer := Timer.create_single_shot(1000, fn () {})
	leave_persistent(persistent)
	timer.start()
	scope.finish()
	owner.release()
	assert observation.fired
	assert owner.arena.usage().used == 0
	timer.fire()
}

fn test_cooperative_timer_queue_outlives_a_nested_recording_scratch_arena() {
	observation := &ArenaTimerObservation{}
	mut timer := Timer.create_single_shot(1000, fn [observation] () {
		mut result := unsafe { &ArenaTimerObservation(observation) }
		result.fired = true
	})
	timer.start()
	mut work := begin_cooperative_work(unsafe { nil }, fn (_ voidptr) {})
	mut scratch := new_arena('recording scratch')
	entry := scratch.enter()
	timer.fire()
	scratch.leave(entry)
	scratch.release()
	work.finish()
	pump_native_events(0.01)
	assert observation.fired
}
