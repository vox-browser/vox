module webidl

@[heap]
struct PromiseAdoptionJobs {
mut:
	jobs []fn ()
	values []string
}

fn (mut jobs PromiseAdoptionJobs) context(id u64) PromiseContext {
	return PromiseContext{
		realm_id: id
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	}
}

fn (mut jobs PromiseAdoptionJobs) drain() {
	mut count := 0
	for jobs.jobs.len > 0 {
		count++
		assert count < 100
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn test_webidl_resolved_promise_adopts_actual_pending_promise_and_resolves_only_once() {
	mut jobs := &PromiseAdoptionJobs{}
	context := jobs.context(811)
	mut source := create_promise_for(context)
	mut adopted := create_resolved_promise_for(context, promise_value(source))
	assert adopted != source
	assert adopted.state == .pending
	assert promise_realm(adopted) == 811
	adopted.reject(string_value('ignored late rejection'))
	adopted.resolve(string_value('ignored late resolution'))
	assert adopted.state == .pending
	source.resolve(string_value('actual source result'))
	assert adopted.state == .pending
	jobs.drain()
	assert adopted.state == .fulfilled
	assert adopted.result.string_value == 'actual source result'
	assert source.is_handled
}

fn test_webidl_promise_adoption_preserves_target_realm_and_source_then_job_realm() {
	mut source_jobs := &PromiseAdoptionJobs{}
	mut target_jobs := &PromiseAdoptionJobs{}
	mut source := create_promise_for(source_jobs.context(812))
	mut target := create_resolved_promise_for(target_jobs.context(813), promise_value(source))
	_ := target.upon_fulfillment(fn [mut target_jobs] (value Value) !Value {
		target_jobs.values << value.string_value
		return undefined_value()
	})
	assert source_jobs.jobs.len == 1
	assert target_jobs.jobs.len == 0
	source.resolve(string_value('across native realms'))
	source_jobs.drain()
	assert target.state == .fulfilled
	assert promise_realm(target) == 813
	assert target_jobs.values.len == 0
	target_jobs.drain()
	assert target_jobs.values == ['across native realms']
}

fn test_webidl_promise_reaction_returning_actual_promise_waits_for_its_rejection() {
	mut jobs := &PromiseAdoptionJobs{}
	context := jobs.context(814)
	mut original := create_promise_for(context)
	mut returned := create_promise_for(context)
	child := original.upon_fulfillment(fn [returned] (_ Value) !Value { return promise_value(returned) })
	original.resolve(undefined_value())
	jobs.drain()
	assert child.state == .pending
	returned.reject(string_value('returned rejection'))
	assert child.state == .pending
	jobs.drain()
	assert child.state == .rejected
	assert child.result.string_value == 'returned rejection'
}

fn test_webidl_promise_self_resolution_rejects_with_source_type_error() {
	mut promise := create_promise()
	promise.resolve(promise_value(promise))
	assert promise.state == .rejected
	assert promise.result.string_value == 'TypeError: Cannot resolve promise with itself'
	assert to_string(promise_value(promise)) or { panic(err) } == '[object Promise]'
}

fn test_webidl_promise_callback_adopts_pending_result_and_uses_callback_context_for_errors() {
	mut jobs := &PromiseAdoptionJobs{}
	context := jobs.context(815)
	mut pending := create_promise_for(context)
	callback := CallbackType{
		callback: fn [pending] (_ Value, _ []Value) !Value { return promise_value(pending) }
		operation_returns_promise: .yes
		promise_context: context
	}
	result := invoke_promise_callback(callback, none, []Value{})
	assert result.state == .pending
	assert promise_realm(result) == 815
	pending.resolve(number_value(23))
	jobs.drain()
	assert result.state == .fulfilled
	assert result.result.number_value == 23
	throwing := CallbackType{
		callback: fn (_ Value, _ []Value) !Value { return error('callback exception') }
		operation_returns_promise: .yes
		promise_context: context
	}
	rejected := invoke_promise_callback(throwing, none, []Value{})
	assert rejected.state == .rejected
	assert rejected.result.string_value == 'callback exception'
	assert promise_realm(rejected) == 815
	invoked := invoke_callback(throwing, none, []Value{}) or { panic(err) }
	assert invoked.kind == .promise
	native := invoked.promise_value_ or { panic('missing callback rejection Promise') }
	assert native.state == .rejected
	assert promise_realm(native) == 815
}
