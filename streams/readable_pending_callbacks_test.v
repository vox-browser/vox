module streams

import webidl

@[heap]
struct StreamCallbackJobs {
mut:
	jobs             []fn ()
	pulls            int
	cancelled_reason string
}

fn (mut jobs StreamCallbackJobs) realm(id u64) StreamRealm {
	return StreamRealm.create_with_promise_context(webidl.PromiseContext{
		realm_id:      id
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	})
}

fn (mut jobs StreamCallbackJobs) drain() {
	mut count := 0
	for jobs.jobs.len > 0 {
		count++
		assert count < 100
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn test_readable_pending_start_and_pull_use_real_promise_reaction_jobs() {
	mut jobs := &StreamCallbackJobs{}
	realm := jobs.realm(701)
	mut start := webidl.create_promise_for(realm.promise_context())
	mut first_pull := webidl.create_promise_for(realm.promise_context())
	mut second_pull := webidl.create_promise_for(realm.promise_context())
	mut stream := ReadableStream.create(realm, UnderlyingSource{
		start_promise: fn [start] () !&webidl.Promise { return start }
		pull_promise:  fn [mut jobs, first_pull, second_pull] () !&webidl.Promise {
			jobs.pulls++
			return if jobs.pulls == 1 { first_pull } else { second_pull }
		}
	}, QueuingStrategy{}) or { panic(err) }
	mut controller := stream.default_controller() or { panic(err) }
	mut reader := stream.get_default_reader() or { panic(err) }
	first_read := reader.read()
	assert !controller.started()
	assert jobs.pulls == 0
	start.resolve(webidl.undefined_value())
	assert !controller.started()
	jobs.drain()
	assert controller.started()
	assert controller.pulling()
	assert jobs.pulls == 1
	controller.enqueue(string_value('first')) or { panic(err) }
	assert first_read.result().value.text == 'first'
	second_read := reader.read()
	assert second_read.state() == .pending
	assert controller.pull_again()
	assert jobs.pulls == 1
	first_pull.resolve(webidl.undefined_value())
	assert controller.pulling()
	assert jobs.pulls == 1
	jobs.drain()
	assert jobs.pulls == 2
	assert controller.pulling()
	controller.enqueue(string_value('second')) or { panic(err) }
	controller.close() or { panic(err) }
	second_pull.resolve(webidl.undefined_value())
	jobs.drain()
	assert second_read.result().value.text == 'second'
	assert stream.state() == .closed
	assert !controller.pulling()
}

fn test_readable_pending_pull_rejection_errors_the_stream_on_its_job() {
	mut jobs := &StreamCallbackJobs{}
	realm := jobs.realm(702)
	mut pull := webidl.create_promise_for(realm.promise_context())
	mut stream := ReadableStream.create(realm, UnderlyingSource{
		pull_promise: fn [pull] () !&webidl.Promise { return pull }
	}, QueuingStrategy{ high_water_mark: 0 }) or { panic(err) }
	mut reader := stream.get_default_reader() or { panic(err) }
	read := reader.read()
	jobs.drain()
	pull.reject(webidl.string_value('pull failed'))
	assert stream.state() == .readable
	assert read.state() == .pending
	jobs.drain()
	assert stream.state() == .errored
	assert read.reason() == 'pull failed'
	assert reader.closed().reason() == 'pull failed'
}

fn test_readable_pending_cancel_retains_settlement_after_closing_and_clearing_algorithms() {
	mut jobs := &StreamCallbackJobs{}
	realm := jobs.realm(703)
	mut cancel := webidl.create_promise_for(realm.promise_context())
	mut stream := ReadableStream.create(realm, underlying_source_from_bindings(BindingsUnderlyingSource{
		cancel_promise: fn [mut jobs, cancel] (reason Value) !&webidl.Promise {
			jobs.cancelled_reason = reason.text
			return cancel
		}
	}), QueuingStrategy{ high_water_mark: 0 }) or { panic(err) }
	jobs.drain()
	result := stream.cancel(string_value('stop'))
	assert stream.state() == .closed
	assert jobs.cancelled_reason == 'stop'
	assert stream.promise_cancel_algorithm_ == none
	assert result.state() == .pending
	cancel.reject(webidl.string_value('cancel failed'))
	assert result.state() == .pending
	jobs.drain()
	assert result.state() == .rejected
	assert result.reason() == 'cancel failed'
	assert result.as_webidl_promise().state == .rejected
	assert webidl.promise_realm(result.as_webidl_promise()) == 703
}

fn test_byte_stream_pending_start_and_pull_preserve_byob_request_until_settlement() {
	mut jobs := &StreamCallbackJobs{}
	realm := jobs.realm(704)
	mut start := webidl.create_promise_for(realm.promise_context())
	mut pull := webidl.create_promise_for(realm.promise_context())
	mut stream := ReadableStream.create(realm, UnderlyingSource{
		type_:         .bytes
		start_promise: fn [start] () !&webidl.Promise { return start }
		pull_promise:  fn [mut jobs, pull] () !&webidl.Promise {
			jobs.pulls++
			return pull
		}
	}, QueuingStrategy{}) or { panic(err) }
	mut reader := stream.get_byob_reader() or { panic(err) }
	read := reader.read(4, 2)
	assert jobs.pulls == 0
	start.resolve(webidl.undefined_value())
	jobs.drain()
	assert jobs.pulls == 1
	mut controller := stream.byte_controller() or { panic(err) }
	request := controller.byob_request() or { panic('missing real BYOB request') }
	mut actual_request := request
	actual_request.write_view([u8(41), 42]) or { panic(err) }
	actual_request.respond(2) or { panic(err) }
	assert read.result().value == [u8(41), 42]
	assert controller.pulling()
	controller.close() or { panic(err) }
	pull.resolve(webidl.undefined_value())
	jobs.drain()
	assert !controller.pulling()
	assert stream.state() == .closed
}

fn test_readable_start_throw_propagates_but_pending_rejection_errors_the_created_stream() {
	mut jobs := &StreamCallbackJobs{}
	realm := jobs.realm(705)
	_ := ReadableStream.create(realm, UnderlyingSource{
		start_promise: fn () !&webidl.Promise { return error('start throw') }
	}, QueuingStrategy{}) or {
		assert err.msg() == 'start throw'
		mut start := webidl.create_promise_for(realm.promise_context())
		mut stream := ReadableStream.create(realm, UnderlyingSource{
			start_promise: fn [start] () !&webidl.Promise { return start }
		}, QueuingStrategy{}) or { panic(err) }
		start.reject(webidl.string_value('start reject'))
		assert stream.state() == .readable
		jobs.drain()
		assert stream.state() == .errored
		assert stream.stored_error() == 'start reject'
		return
	}
	panic('start exception did not propagate')
}
