module webidl

@[heap]
struct PromiseTestJobs {
mut:
	jobs []fn ()
	seen []string
}

fn (mut jobs PromiseTestJobs) run_one() {
	job := jobs.jobs[0]
	jobs.jobs.delete(0)
	job()
}

fn test_promise_host_jobs_preserve_realm_and_defer_reactions() {
	mut jobs := &PromiseTestJobs{}
	context := PromiseContext{
		realm_id:      42
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	}
	mut promise := create_promise_for(context)
	mut child := promise.upon_fulfillment(fn [mut jobs] (value Value) !Value {
		jobs.seen << 'first'
		return number_value(value.number_value + 1)
	})
	grandchild := child.upon_fulfillment(fn [mut jobs] (value Value) !Value {
		jobs.seen << 'second'
		return value
	})
	promise.resolve(number_value(7))
	promise.reject(string_value('ignored'))
	assert promise.state == .fulfilled
	assert child.state == .pending
	assert grandchild.state == .pending
	assert jobs.seen.len == 0
	assert jobs.jobs.len == 1
	assert promise_realm(child) == 42
	jobs.run_one()
	assert child.result.number_value == 8
	assert grandchild.state == .pending
	assert jobs.seen == ['first']
	jobs.run_one()
	assert grandchild.result.number_value == 8
	assert jobs.seen == ['first', 'second']
	late := promise.upon_fulfillment(fn [mut jobs] (value Value) !Value {
		jobs.seen << 'late'
		return value
	})
	assert late.state == .pending
	jobs.run_one()
	assert late.state == .fulfilled
	assert jobs.seen == ['first', 'second', 'late']
}

fn test_promise_host_observers_run_in_jobs_and_rejections_propagate() {
	mut jobs := &PromiseTestJobs{}
	mut promise := create_promise_for(PromiseContext{
		realm_id:      9
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	})
	child := promise.upon_rejection(fn [mut jobs] (reason Value) !Value {
		jobs.seen << reason.string_value
		return error('translated rejection')
	})
	wait_for_all([promise], fn [mut jobs] (_ []Value) { jobs.seen << 'success' },
		fn [mut jobs] (reason Value) { jobs.seen << 'observer ${reason.string_value}' })
	promise.reject(string_value('failure'))
	assert jobs.jobs.len == 2
	assert jobs.seen.len == 0
	jobs.run_one()
	assert child.state == .rejected
	assert child.result.string_value == 'translated rejection'
	jobs.run_one()
	assert jobs.seen == ['failure', 'observer failure']
}
