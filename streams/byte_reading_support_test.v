module streams

import webidl

@[heap]
struct ByteSupportJobs {
mut:
	jobs      []fn ()
	pulls     int
	cancelled []webidl.Value
}

fn (mut jobs ByteSupportJobs) realm() StreamRealm {
	return StreamRealm.create_with_promise_context(webidl.PromiseContext{
		realm_id:      91
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	})
}

fn (mut jobs ByteSupportJobs) drain() {
	mut count := 0
	for jobs.jobs.len > 0 {
		count++
		assert count < 100
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn test_source_byte_reading_setup_initializes_actual_controller_and_owning_start_job() {
	mut jobs := &ByteSupportJobs{}
	realm := jobs.realm()
	mut stream := ReadableStream.create_for_internal()
	stream.set_up_with_byte_reading_support_in_realm(realm, none, none, 0)
	assert stream.realm().id == 91
	assert stream.is_byte_stream() && stream.is_readable() && !stream.locked() && !stream.disturbed()
	assert stream.desired_size()? == 0 && stream.queued_chunks() == 0
	assert stream.auto_allocate_size_ == none
	assert !stream.started_ && jobs.jobs.len == 1
	jobs.drain()
	assert stream.started_
	mut reader := stream.get_default_reader()!
	read := reader.read()
	assert read.state() == .pending && read.realm().id == 91
	stream.enqueue(bytes_value([u8(1), 2]))!
	stream.close()
	assert read.state() == .fulfilled && read.result().value.bytes_ == [u8(1), 2]
	assert reader.read().result().done
}

fn test_source_byte_reading_wrappers_forward_pending_pull_cancel_and_original_reasons() {
	mut jobs := &ByteSupportJobs{}
	realm := jobs.realm()
	mut pull_promise := webidl.create_promise_for(realm.promise_context())
	mut cancel_promise := webidl.create_promise_for(realm.promise_context())
	mut stream := ReadableStream.create_for_internal()
	stream.set_up_with_byte_reading_support_in_realm(realm, fn [mut jobs, pull_promise] () !&webidl.Promise {
		jobs.pulls++
		return pull_promise
	}, fn [mut jobs, cancel_promise] (reason Value) !&webidl.Promise {
		jobs.cancelled << stream_value_to_webidl(reason)
		return cancel_promise
	}, 0)
	jobs.drain()
	mut reader := stream.get_default_reader()!
	read := reader.read()
	assert jobs.pulls == 1 && stream.pulling_
	stream.enqueue(bytes_value([u8(3)]))!
	assert read.state() == .fulfilled && stream.pulling_
	pull_promise.resolve(webidl.undefined_value())
	jobs.drain()
	assert !stream.pulling_
	exception := webidl.DOMException.create_record('AbortError', 'source cancellation')
	reason := webidl.dom_exception_value_for_record(exception)
	cancellation := reader.cancel(runtime_value(reason))
	assert cancellation.state() == .pending
	assert jobs.cancelled.len == 1 && jobs.cancelled[0].dom_exception_? == exception
	cancel_promise.resolve(webidl.undefined_value())
	jobs.drain()
	assert cancellation.state() == .fulfilled
}

fn test_source_byte_reading_wrapper_errors_preserve_the_original_value() {
	mut jobs := &ByteSupportJobs{}
	realm := jobs.realm()
	exception := webidl.DOMException.create_record('AbortError', 'source pull failure')
	reason := webidl.dom_exception_value_for_record(exception)
	mut stream := ReadableStream.create_for_internal()
	stream.set_up_with_byte_reading_support_in_realm(realm, fn [reason] () !&webidl.Promise {
		return webidl.throw_value(reason)
	}, none, 0)
	jobs.drain()
	mut reader := stream.get_default_reader()!
	read := reader.read()
	assert read.state() == .pending
	jobs.drain()
	assert read.state() == .rejected
	assert stream.stored_error_value().dom_exception_? == exception
	assert read.as_webidl_promise().result.dom_exception_? == exception
}
