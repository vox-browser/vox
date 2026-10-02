module streams

import webidl

@[heap]
struct WritableCallbackJobs {
mut:
	jobs []fn ()
	writes []string
	abort_reason string
}

fn (mut jobs WritableCallbackJobs) realm(id u64) StreamRealm {
	return StreamRealm.create_with_promise_context(webidl.PromiseContext{
		realm_id: id
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	})
}

fn (mut jobs WritableCallbackJobs) drain() {
	mut count := 0
	for jobs.jobs.len > 0 {
		count++
		assert count < 100
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn test_pending_sink_start_writes_and_close_preserve_in_flight_requests_and_backpressure() {
	mut jobs := &WritableCallbackJobs{}
	realm := jobs.realm(721)
	mut start := webidl.create_promise_for(realm.promise_context())
	mut first := webidl.create_promise_for(realm.promise_context())
	mut second := webidl.create_promise_for(realm.promise_context())
	mut close := webidl.create_promise_for(realm.promise_context())
	mut stream := WritableStream.create(realm, UnderlyingSink{
		start_promise: fn [start] () !&webidl.Promise { return start }
		write_promise: fn [mut jobs, first, second] (chunk Value) !&webidl.Promise {
			jobs.writes << chunk.text
			return if jobs.writes.len == 1 { first } else { second }
		}
		close_promise: fn [close] () !&webidl.Promise { return close }
	}, QueuingStrategy{}) or { panic(err) }
	mut writer := stream.get_writer() or { panic(err) }
	write1 := writer.write(string_value('one'))
	write2 := writer.write(string_value('two'))
	assert !stream.controller().started()
	assert jobs.writes.len == 0
	assert write1.state() == .pending
	assert writer.ready().state() == .pending
	start.resolve(webidl.undefined_value())
	jobs.drain()
	assert jobs.writes == ['one']
	assert stream.in_flight_write_request() or { panic('missing in flight write') } == write1
	assert stream.queue_total_size() == 2
	first.resolve(webidl.undefined_value())
	assert write1.state() == .pending
	jobs.drain()
	assert write1.state() == .fulfilled
	assert write2.state() == .pending
	assert jobs.writes == ['one', 'two']
	assert writer.ready().state() == .pending
	second.resolve(webidl.undefined_value())
	jobs.drain()
	assert write2.state() == .fulfilled
	assert writer.ready().state() == .fulfilled
	assert stream.queue_total_size() == 0
	closed := writer.close()
	assert closed.state() == .pending
	assert stream.state() == .writable
	assert stream.in_flight_close_request() or { panic('missing in flight close') } == closed
	assert stream.promise_close_algorithm_ == none
	close.resolve(webidl.undefined_value())
	assert closed.state() == .pending
	jobs.drain()
	assert closed.state() == .fulfilled
	assert writer.closed().state() == .fulfilled
	assert stream.state() == .closed
}

fn test_pending_sink_write_rejection_rejects_in_flight_and_queued_requests() {
	mut jobs := &WritableCallbackJobs{}
	realm := jobs.realm(722)
	mut write := webidl.create_promise_for(realm.promise_context())
	mut stream := WritableStream.create(realm, UnderlyingSink{
		write_promise: fn [mut jobs, write] (chunk Value) !&webidl.Promise {
			jobs.writes << chunk.text
			return write
		}
	}, QueuingStrategy{}) or { panic(err) }
	mut writer := stream.get_writer() or { panic(err) }
	first := writer.write(string_value('first'))
	second := writer.write(string_value('second'))
	closed := writer.close()
	jobs.drain()
	assert jobs.writes == ['first']
	write.reject(webidl.string_value('sink write failure'))
	assert first.state() == .pending
	jobs.drain()
	assert first.reason() == 'sink write failure'
	assert second.reason() == 'sink write failure'
	assert closed.reason() == 'sink write failure'
	assert writer.closed().reason() == 'sink write failure'
	assert writer.closed().as_webidl_promise().is_handled
	assert stream.state() == .errored
	assert stream.written_values().len == 0
	assert jobs.writes == ['first']
}

fn test_pending_sink_abort_waits_for_in_flight_write_and_then_its_own_settlement() {
	mut jobs := &WritableCallbackJobs{}
	realm := jobs.realm(723)
	mut write := webidl.create_promise_for(realm.promise_context())
	mut abort := webidl.create_promise_for(realm.promise_context())
	mut stream := WritableStream.create(realm, UnderlyingSink{
		write_promise: fn [write] (_ Value) !&webidl.Promise { return write }
		abort_promise: fn [mut jobs, abort] (reason Value) !&webidl.Promise {
			jobs.abort_reason = reason.text
			return abort
		}
	}, QueuingStrategy{}) or { panic(err) }
	mut writer := stream.get_writer() or { panic(err) }
	jobs.drain()
	written := writer.write(string_value('pending'))
	aborted := writer.abort(string_value('stop'))
	assert stream.state() == .erroring
	assert stream.controller().signal().aborted()
	assert jobs.abort_reason == ''
	assert aborted.state() == .pending
	write.resolve(webidl.undefined_value())
	jobs.drain()
	assert written.state() == .fulfilled
	assert stream.state() == .errored
	assert jobs.abort_reason == 'stop'
	assert aborted.state() == .pending
	assert writer.closed().state() == .pending
	abort.resolve(webidl.undefined_value())
	jobs.drain()
	assert aborted.state() == .fulfilled
	assert writer.closed().reason() == 'stop'
}

fn test_pending_sink_abort_rejection_preserves_abort_reason_and_original_stream_error() {
	mut jobs := &WritableCallbackJobs{}
	realm := jobs.realm(724)
	mut abort := webidl.create_promise_for(realm.promise_context())
	mut stream := WritableStream.create(realm, UnderlyingSink{
		abort_promise: fn [abort] (_ Value) !&webidl.Promise { return abort }
	}, QueuingStrategy{}) or { panic(err) }
	mut writer := stream.get_writer() or { panic(err) }
	jobs.drain()
	aborted := writer.abort(string_value('original stop'))
	assert writer.closed().state() == .pending
	abort.reject(webidl.string_value('abort failed'))
	jobs.drain()
	assert aborted.reason() == 'abort failed'
	assert writer.closed().reason() == 'original stop'
	assert stream.stored_error() == 'original stop'
}

fn test_pending_close_success_resolves_abort_requested_while_close_is_in_flight() {
	mut jobs := &WritableCallbackJobs{}
	realm := jobs.realm(725)
	mut close := webidl.create_promise_for(realm.promise_context())
	mut stream := WritableStream.create(realm, UnderlyingSink{
		close_promise: fn [close] () !&webidl.Promise { return close }
	}, QueuingStrategy{}) or { panic(err) }
	mut writer := stream.get_writer() or { panic(err) }
	jobs.drain()
	closed := writer.close()
	aborted := writer.abort(string_value('stop during close'))
	assert stream.state() == .erroring
	assert closed.state() == .pending
	assert aborted.state() == .pending
	close.resolve(webidl.undefined_value())
	jobs.drain()
	assert closed.state() == .fulfilled
	assert aborted.state() == .fulfilled
	assert writer.closed().state() == .fulfilled
	assert stream.state() == .closed
	assert stream.stored_error() == ''
}

fn test_pending_sink_start_rejection_marks_started_before_erroring_queued_writes() {
	mut jobs := &WritableCallbackJobs{}
	realm := jobs.realm(726)
	mut start := webidl.create_promise_for(realm.promise_context())
	mut stream := WritableStream.create(realm, UnderlyingSink{
		start_promise: fn [start] () !&webidl.Promise { return start }
	}, QueuingStrategy{}) or { panic(err) }
	mut writer := stream.get_writer() or { panic(err) }
	written := writer.write(string_value('never sent'))
	start.reject(webidl.string_value('start rejected'))
	assert !stream.controller().started()
	jobs.drain()
	assert stream.controller().started()
	assert stream.state() == .errored
	assert written.reason() == 'start rejected'
	assert writer.closed().reason() == 'start rejected'
}
