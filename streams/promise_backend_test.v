module streams

import webidl

@[heap]
struct PromiseBackendJobs {
mut:
	jobs []fn ()
	pulls int
}

fn (mut jobs PromiseBackendJobs) realm(id u64) StreamRealm {
	return StreamRealm.create_with_promise_context(webidl.PromiseContext{
		realm_id: id
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	})
}

fn (mut jobs PromiseBackendJobs) drain() {
	for jobs.jobs.len > 0 {
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn test_public_pending_promise_record_retains_its_actual_backend_and_schedules_reactions() {
	mut jobs := &PromiseBackendJobs{}
	mut record := &VoidPromise{ realm_: jobs.realm(711) }
	mut native := record.as_webidl_promise()
	assert native == record.as_webidl_promise()
	assert native.state == .pending
	assert webidl.promise_realm(native) == 711
	mut observation := &PromiseBackendJobs{}
	webidl.react_to_promise(mut native, fn [mut observation] (_ webidl.Value) !webidl.Value {
		observation.pulls++
		return webidl.undefined_value()
	}, fn (_ webidl.Value) !webidl.Value { panic('unexpected rejection') })
	record.resolve()
	assert record.state() == .fulfilled
	assert native.state == .fulfilled
	assert observation.pulls == 0
	jobs.drain()
	assert observation.pulls == 1
}

fn test_public_promise_records_settle_without_prior_backend_access() {
	mut fulfilled := &VoidPromise{}
	fulfilled.resolve()
	assert fulfilled.as_webidl_promise().state == .fulfilled
	mut rejected := &VoidPromise{}
	rejected.reject('actual rejection')
	assert rejected.as_webidl_promise().state == .rejected
	assert rejected.as_webidl_promise().result.string_value == 'actual rejection'
	mut already_settled := &VoidPromise{ state_: .rejected, reason_: 'constructed rejection' }
	assert already_settled.as_webidl_promise().state == .rejected
	assert already_settled.as_webidl_promise().result.string_value == 'constructed rejection'
}
