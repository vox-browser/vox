module browserjs

import streams
import webidl

@[heap]
struct NativeReadableRejectionJobs {
mut:
	jobs []fn ()
}

fn (mut jobs NativeReadableRejectionJobs) realm() streams.StreamRealm {
	return streams.StreamRealm.create_with_promise_context(webidl.PromiseContext{
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	})
}

fn (mut jobs NativeReadableRejectionJobs) drain() {
	mut count := 0
	for jobs.jobs.len > 0 {
		count++
		assert count < 100
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn native_readable_rejection(runtime &Runtime, promise &webidl.Promise) !voidptr {
	assert promise.state == .rejected
	return runtime.actual_webidl_value(promise.result)
}

fn test_readable_error_retains_actual_jsc_reason_for_pending_future_and_closed_readers() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reason := runtime.evaluate_host_value('globalThis.reasonCoercions=0;globalThis.actualReason={toString(){reasonCoercions++;throw new Error("must not coerce")}};actualReason')!
	native_reason := runtime.webidl_value(reason)!
	mut stream := streams.ReadableStream.create(streams.StreamRealm{}, streams.UnderlyingSource{}, streams.QueuingStrategy{ high_water_mark: 0 })!
	mut reader := stream.get_default_reader()!
	first := reader.read()
	second := reader.read()
	closed := reader.closed()
	stream.error_value(native_reason)
	assert native_readable_rejection(runtime, first.as_webidl_promise())! == reason
	assert native_readable_rejection(runtime, second.as_webidl_promise())! == reason
	assert native_readable_rejection(runtime, closed.as_webidl_promise())! == reason
	assert runtime.actual_webidl_value(stream.stored_error_value())! == reason
	assert native_readable_rejection(runtime, reader.read().as_webidl_promise())! == reason
	reader.release_lock()!
	assert native_readable_rejection(runtime, stream.cancel(streams.undefined_value()).as_webidl_promise())! == reason
	mut later_reader := stream.get_default_reader()!
	assert native_readable_rejection(runtime, later_reader.closed().as_webidl_promise())! == reason
	assert native_readable_rejection(runtime, later_reader.read().as_webidl_promise())! == reason
	assert runtime.evaluate_host('reasonCoercions')! == '0'
}

fn test_byte_stream_error_preserves_actual_symbol_for_pending_byob_and_future_reads() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reason := runtime.evaluate_host_value('Symbol("actual byte stream rejection")')!
	native_reason := runtime.webidl_value(reason)!
	mut stream := streams.ReadableStream.create(streams.StreamRealm{}, streams.UnderlyingSource{ type_: .bytes }, streams.QueuingStrategy{})!
	mut reader := stream.get_byob_reader()!
	first := reader.read(4, 1)
	second := reader.read(6, 2)
	stream.error_value(native_reason)
	assert native_readable_rejection(runtime, first.as_webidl_promise())! == reason
	assert native_readable_rejection(runtime, second.as_webidl_promise())! == reason
	assert native_readable_rejection(runtime, reader.closed().as_webidl_promise())! == reason
	assert native_readable_rejection(runtime, reader.read(4, 1).as_webidl_promise())! == reason
	reader.release_lock()!
	mut later_reader := stream.get_byob_reader()!
	assert native_readable_rejection(runtime, later_reader.closed().as_webidl_promise())! == reason
	assert native_readable_rejection(runtime, later_reader.read(4, 1).as_webidl_promise())! == reason
}

fn test_pending_source_start_pull_and_cancel_rejections_keep_actual_jsc_value_on_owner_jobs() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reason := runtime.evaluate_host_value('({source:"actual pending callback rejection"})')!
	native_reason := runtime.webidl_value(reason)!
	mut jobs := &NativeReadableRejectionJobs{}
	realm := jobs.realm()
	mut start := webidl.create_promise_for(realm.promise_context())
	mut starting := streams.ReadableStream.create(realm, streams.UnderlyingSource{
		start_promise: fn [start] () !&webidl.Promise { return start }
	}, streams.QueuingStrategy{ high_water_mark: 0 })!
	mut starting_reader := starting.get_default_reader()!
	starting_read := starting_reader.read()
	start.reject(native_reason)
	assert starting_read.state() == .pending
	jobs.drain()
	assert native_readable_rejection(runtime, starting_read.as_webidl_promise())! == reason
	mut pull := webidl.create_promise_for(realm.promise_context())
	mut pulling := streams.ReadableStream.create(realm, streams.UnderlyingSource{
		pull_promise: fn [pull] () !&webidl.Promise { return pull }
	}, streams.QueuingStrategy{ high_water_mark: 0 })!
	mut pulling_reader := pulling.get_default_reader()!
	pulling_read := pulling_reader.read()
	jobs.drain()
	pull.reject(native_reason)
	assert pulling_read.state() == .pending
	jobs.drain()
	assert native_readable_rejection(runtime, pulling_read.as_webidl_promise())! == reason
	mut cancel := webidl.create_promise_for(realm.promise_context())
	mut cancelling := streams.ReadableStream.create(realm, streams.UnderlyingSource{
		cancel_promise: fn [cancel] (_ streams.Value) !&webidl.Promise { return cancel }
	}, streams.QueuingStrategy{ high_water_mark: 0 })!
	jobs.drain()
	cancelled := cancelling.cancel(streams.undefined_value())
	cancel.reject(native_reason)
	assert cancelled.state() == .pending
	jobs.drain()
	assert native_readable_rejection(runtime, cancelled.as_webidl_promise())! == reason
}
