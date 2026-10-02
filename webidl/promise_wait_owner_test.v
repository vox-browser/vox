module webidl

@[heap]
struct WaitOwnerJobs {
mut:
	jobs          []fn ()
	realm_entries int
	realm_depth   int
}

fn (mut owner WaitOwnerJobs) context() PromiseContext {
	return PromiseContext{
		realm_id:           47
		job_scheduler:      fn [mut owner] (steps fn ()) {
			owner.jobs << steps
		}
		realm_steps_runner: fn [mut owner] (steps fn ()) {
			owner.realm_entries++
			owner.realm_depth++
			defer { owner.realm_depth-- }
			steps()
		}
	}
}

fn (mut owner WaitOwnerJobs) drain() {
	for owner.jobs.len > 0 {
		job := owner.jobs[0]
		owner.jobs.delete(0)
		job()
	}
}

fn test_wait_for_all_retains_supplied_owner_and_reaction_context_for_pending_inputs() {
	mut owner := &WaitOwnerJobs{}
	context := owner.context()
	mut first := create_promise_for(context)
	mut second := create_promise_for(context)
	mut combined := get_promise_for_wait_for_all_for(context, [first, second])
	assert promise_realm(combined) == 47
	combined_context := promise_context(combined)
	_ = combined_context.realm_steps_runner or { panic('missing aggregate realm runner') }
	child := combined.upon_fulfillment(fn (values Value) !Value {
		assert values.sequence_value.len == 2
		return undefined_value()
	})
	assert promise_realm(child) == 47
	child_context := promise_context(child)
	_ = child_context.realm_steps_runner or { panic('missing child realm runner') }
	second.resolve(string_value('second'))
	owner.drain()
	assert combined.state == .pending && owner.realm_entries == 0
	first.resolve(string_value('first'))
	assert combined.state == .pending
	owner.drain()
	assert combined.state == .fulfilled && child.state == .fulfilled
	assert combined.result.sequence_value[0].string_value == 'first'
	assert combined.result.sequence_value[1].string_value == 'second'
	assert owner.realm_entries == 1 && owner.realm_depth == 0
}

fn test_wait_for_all_empty_and_original_rejection_settle_in_supplied_owner() {
	mut owner := &WaitOwnerJobs{}
	context := owner.context()
	empty := get_promise_for_wait_for_all_for(context, []&Promise{})
	assert empty.state == .fulfilled && promise_realm(empty) == 47
	assert owner.realm_entries == 1 && owner.realm_depth == 0
	mut pending := create_promise_for(context)
	combined := get_promise_for_wait_for_all_for(context, [pending])
	record := DOMException.create_record('OperationError', 'original wait reason')
	pending.reject(dom_exception_value_for_record(record))
	assert combined.state == .pending
	owner.drain()
	assert combined.state == .rejected
	assert voidptr(combined.result.dom_exception_?) == voidptr(record)
	assert promise_realm(combined) == 47 && owner.realm_entries == 2
}
