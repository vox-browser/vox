module streams

import webidl

@[heap]
struct TransformCallbackJobs {
mut:
	jobs []fn ()
	transforms []string
}

fn (mut jobs TransformCallbackJobs) realm(id u64) StreamRealm {
	return StreamRealm.create_with_promise_context(webidl.PromiseContext{
		realm_id: id
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	})
}

fn (mut jobs TransformCallbackJobs) drain() {
	mut count := 0
	for jobs.jobs.len > 0 {
		count++
		assert count < 200
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn test_transform_shared_pending_start_and_pending_transform_hold_both_controllers_and_write() {
	mut jobs := &TransformCallbackJobs{}
	realm := jobs.realm(751)
	mut start := webidl.create_promise_for(realm.promise_context())
	mut transformed := webidl.create_promise_for(realm.promise_context())
	mut stream := TransformStream.create(realm, Transformer{
		start_promise: fn [start] () !&webidl.Promise { return start }
		transform_promise: fn [mut jobs, transformed] (chunk Value) !&webidl.Promise {
			jobs.transforms << chunk.text
			return transformed
		}
	}, QueuingStrategy{}, QueuingStrategy{}) or { panic(err) }
	mut readable := stream.readable()
	mut writable := stream.writable()
	mut writer := writable.get_writer() or { panic(err) }
	mut reader := readable.get_default_reader() or { panic(err) }
	written := writer.write(string_value('input'))
	read := reader.read()
	jobs.drain()
	assert !readable.default_controller_.started()
	assert !writable.controller().started()
	assert jobs.transforms.len == 0
	start.resolve(webidl.undefined_value())
	jobs.drain()
	assert readable.default_controller_.started()
	assert writable.controller().started()
	assert jobs.transforms == ['input']
	assert written.state() == .pending
	assert writable.in_flight_write_request() or { panic('missing transform write') } == written
	mut controller := stream.controller()
	controller.enqueue(string_value('actual native output')) or { panic(err) }
	assert read.result().value.text == 'actual native output'
	assert written.state() == .pending
	transformed.resolve(webidl.undefined_value())
	jobs.drain()
	assert written.state() == .fulfilled
}

fn test_transform_backpressure_wait_marks_write_in_flight_before_starting_callback() {
	mut jobs := &TransformCallbackJobs{}
	realm := jobs.realm(752)
	mut transformed := webidl.create_promise_for(realm.promise_context())
	mut stream := TransformStream.create(realm, Transformer{
		transform_promise: fn [mut jobs, transformed] (chunk Value) !&webidl.Promise {
			jobs.transforms << chunk.text
			return transformed
		}
	}, QueuingStrategy{}, QueuingStrategy{}) or { panic(err) }
	mut writable := stream.writable()
	mut writer := writable.get_writer() or { panic(err) }
	jobs.drain()
	written := writer.write(string_value('blocked input'))
	assert writable.in_flight_write_request() or { panic('missing blocked in flight write') } == written
	assert jobs.transforms.len == 0
	mut readable := stream.readable()
	mut reader := readable.get_default_reader() or { panic(err) }
	_ := reader.read()
	assert jobs.transforms.len == 0
	jobs.drain()
	assert jobs.transforms == ['blocked input']
	transformed.reject(webidl.string_value('transform failure'))
	jobs.drain()
	assert written.reason() == 'transform failure'
	assert readable.state() == .errored
	assert writable.state() == .errored
}

// Ladybird daead28014e59f15bc0862901d10618adf31856d: cancellation can
// clear the transform algorithm before a queued write continuation resumes.
fn test_transform_write_released_by_read_then_cancel_does_not_enqueue_after_close() {
	mut jobs := &TransformCallbackJobs{}
	realm := jobs.realm(758)
	mut stream := TransformStream.create(realm, Transformer{}, QueuingStrategy{}, QueuingStrategy{}) or { panic(err) }
	mut readable := stream.readable()
	mut writable := stream.writable()
	mut reader := readable.get_default_reader() or { panic(err) }
	mut writer := writable.get_writer() or { panic(err) }
	jobs.drain()
	written := writer.write(string_value('blocked input'))
	jobs.drain()
	assert written.state() == .pending
	read := reader.read()
	cancelled := reader.cancel(undefined_value())
	assert stream.transform_algorithm_ == none
	assert readable.state() == .closed
	jobs.drain()
	assert cancelled.state() == .fulfilled
	assert read.result().done
	assert written.state() == .fulfilled
}

fn test_transform_pending_flush_retains_finish_and_output_until_fulfillment() {
	mut jobs := &TransformCallbackJobs{}
	realm := jobs.realm(753)
	mut flush := webidl.create_promise_for(realm.promise_context())
	mut stream := TransformStream.create(realm, Transformer{
		flush_promise: fn [flush] () !&webidl.Promise { return flush }
	}, QueuingStrategy{}, QueuingStrategy{}) or { panic(err) }
	mut writable := stream.writable()
	mut readable := stream.readable()
	mut writer := writable.get_writer() or { panic(err) }
	mut reader := readable.get_default_reader() or { panic(err) }
	jobs.drain()
	closed := writer.close()
	read := reader.read()
	assert closed.state() == .pending
	assert readable.state() == .readable
	assert stream.promise_flush_algorithm_ == none
	mut controller := stream.controller()
	controller.enqueue(string_value('late flush output')) or { panic(err) }
	assert read.result().value.text == 'late flush output'
	assert closed.state() == .pending
	flush.resolve(webidl.undefined_value())
	jobs.drain()
	assert closed.state() == .fulfilled
	assert readable.state() == .closed
	assert writer.closed().state() == .fulfilled
}

fn test_transform_pending_flush_rejection_errors_readable_and_writable_close() {
	mut jobs := &TransformCallbackJobs{}
	realm := jobs.realm(754)
	mut flush := webidl.create_promise_for(realm.promise_context())
	mut stream := TransformStream.create(realm, Transformer{
		flush_promise: fn [flush] () !&webidl.Promise { return flush }
	}, QueuingStrategy{}, QueuingStrategy{}) or { panic(err) }
	mut writable := stream.writable()
	mut writer := writable.get_writer() or { panic(err) }
	jobs.drain()
	closed := writer.close()
	flush.reject(webidl.string_value('flush failure'))
	assert closed.state() == .pending
	jobs.drain()
	assert closed.reason() == 'flush failure'
	assert stream.readable().state() == .errored
	assert writable.state() == .errored
}

fn test_transform_pending_readable_cancel_waits_and_unblocks_the_existing_write() {
	mut jobs := &TransformCallbackJobs{}
	realm := jobs.realm(755)
	mut cancel := webidl.create_promise_for(realm.promise_context())
	mut stream := TransformStream.create(realm, Transformer{
		cancel_promise: fn [cancel] (_ Value) !&webidl.Promise { return cancel }
	}, QueuingStrategy{}, QueuingStrategy{}) or { panic(err) }
	mut readable := stream.readable()
	mut writable := stream.writable()
	mut writer := writable.get_writer() or { panic(err) }
	jobs.drain()
	written := writer.write(string_value('backpressure wait'))
	cancelled := readable.cancel(string_value('cancel transform'))
	assert cancelled.state() == .pending
	assert written.state() == .pending
	assert writable.state() == .writable
	cancel.resolve(webidl.undefined_value())
	jobs.drain()
	assert cancelled.state() == .fulfilled
	assert written.reason() == 'cancel transform'
	assert writer.closed().reason() == 'cancel transform'
	assert writable.state() == .errored
}

fn test_transform_pending_abort_uses_the_shared_finish_promise_and_rejects_on_cancel_failure() {
	mut jobs := &TransformCallbackJobs{}
	realm := jobs.realm(756)
	mut cancel := webidl.create_promise_for(realm.promise_context())
	mut stream := TransformStream.create(realm, Transformer{
		cancel_promise: fn [cancel] (_ Value) !&webidl.Promise { return cancel }
	}, QueuingStrategy{}, QueuingStrategy{}) or { panic(err) }
	mut writable := stream.writable()
	mut writer := writable.get_writer() or { panic(err) }
	jobs.drain()
	aborted := writer.abort(string_value('abort transform'))
	finish := stream.controller().finish_promise() or { panic('missing finish promise') }
	assert transform_stream_default_source_cancel_algorithm(mut stream, string_value('other reason')) == finish
	assert aborted.state() == .pending
	cancel.reject(webidl.string_value('transform cancel failure'))
	jobs.drain()
	assert aborted.reason() == 'transform cancel failure'
	assert stream.readable().stored_error() == 'transform cancel failure'
}

fn test_transform_pending_start_rejection_errors_both_sides_after_the_owner_job() {
	mut jobs := &TransformCallbackJobs{}
	realm := jobs.realm(757)
	mut start := webidl.create_promise_for(realm.promise_context())
	mut stream := TransformStream.create(realm, Transformer{
		start_promise: fn [start] () !&webidl.Promise { return start }
	}, QueuingStrategy{}, QueuingStrategy{}) or { panic(err) }
	start.reject(webidl.string_value('transform startup failure'))
	assert stream.readable().state() == .readable
	assert stream.writable().state() == .writable
	jobs.drain()
	assert stream.readable().stored_error() == 'transform startup failure'
	assert stream.writable().stored_error() == 'transform startup failure'
}
