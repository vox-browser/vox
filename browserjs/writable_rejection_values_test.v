module browserjs

import streams
import webidl

@[heap]
struct NativeWritableRejectionJobs {
mut:
	jobs []fn ()
	seen ?webidl.Value
}

fn (mut jobs NativeWritableRejectionJobs) realm() streams.StreamRealm {
	return streams.StreamRealm.create_with_promise_context(webidl.PromiseContext{
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	})
}

fn (mut jobs NativeWritableRejectionJobs) drain() {
	mut count := 0
	for jobs.jobs.len > 0 {
		count++
		assert count < 100
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn native_writable_rejection(runtime &Runtime, promise &webidl.Promise) !voidptr {
	assert promise.state == .rejected
	return runtime.actual_webidl_value(promise.result)
}

fn test_pending_write_rejection_preserves_actual_reason_for_queue_closed_ready_and_future_writer() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reason := runtime.evaluate_host_value('globalThis.writeReasonCoercions=0;({toString(){writeReasonCoercions++;throw new Error("must not coerce")}})')!
	native_reason := runtime.webidl_value(reason)!
	mut jobs := &NativeWritableRejectionJobs{}
	realm := jobs.realm()
	mut write := webidl.create_promise_for(realm.promise_context())
	mut stream := streams.WritableStream.create(realm, streams.UnderlyingSink{
		write_promise: fn [write] (_ streams.Value) !&webidl.Promise { return write }
	}, streams.QueuingStrategy{})!
	jobs.drain()
	mut writer := stream.get_writer()!
	first := writer.write(streams.undefined_value())
	second := writer.write(streams.undefined_value())
	ready := writer.ready()
	closed := writer.closed()
	close := writer.close()
	write.reject(native_reason)
	assert first.state() == .pending
	jobs.drain()
	assert native_writable_rejection(runtime, first.as_webidl_promise())! == reason
	assert native_writable_rejection(runtime, second.as_webidl_promise())! == reason
	// WritableStreamClose resolves a backpressured ready promise before the
	// later write rejection installs the writer's new rejected capability.
	assert ready.state() == .fulfilled
	assert native_writable_rejection(runtime, writer.ready().as_webidl_promise())! == reason
	assert native_writable_rejection(runtime, closed.as_webidl_promise())! == reason
	assert native_writable_rejection(runtime, close.as_webidl_promise())! == reason
	assert native_writable_rejection(runtime, writer.write(streams.undefined_value()).as_webidl_promise())! == reason
	assert runtime.actual_webidl_value(stream.stored_error_value())! == reason
	writer.release_lock()
	mut later_writer := stream.get_writer()!
	assert native_writable_rejection(runtime, later_writer.closed().as_webidl_promise())! == reason
	assert native_writable_rejection(runtime, later_writer.ready().as_webidl_promise())! == reason
	assert native_writable_rejection(runtime, later_writer.close().as_webidl_promise())! == reason
	assert runtime.evaluate_host('writeReasonCoercions')! == '0'
}

fn test_pending_sink_start_and_controller_error_retain_actual_symbol_reason() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reason := runtime.evaluate_host_value('Symbol("actual sink rejection")')!
	native_reason := runtime.webidl_value(reason)!
	mut jobs := &NativeWritableRejectionJobs{}
	realm := jobs.realm()
	mut start := webidl.create_promise_for(realm.promise_context())
	mut stream := streams.WritableStream.create(realm, streams.UnderlyingSink{
		start_promise: fn [start] () !&webidl.Promise { return start }
	}, streams.QueuingStrategy{})!
	mut writer := stream.get_writer()!
	written := writer.write(streams.undefined_value())
	start.reject(native_reason)
	jobs.drain()
	assert native_writable_rejection(runtime, written.as_webidl_promise())! == reason
	assert native_writable_rejection(runtime, writer.closed().as_webidl_promise())! == reason
	mut controlled := streams.WritableStream.create(realm, streams.UnderlyingSink{}, streams.QueuingStrategy{})!
	jobs.drain()
	mut controlled_writer := controlled.get_writer()!
	mut controller := controlled.controller()
	streams.writable_stream_default_controller_error(mut controller, streams.runtime_value(native_reason))
	assert native_writable_rejection(runtime, controlled_writer.ready().as_webidl_promise())! == reason
	assert native_writable_rejection(runtime, controlled_writer.closed().as_webidl_promise())! == reason
}

fn test_pending_abort_callback_receives_actual_reason_and_rejects_with_actual_returned_error() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reason := runtime.evaluate_host_value('({reason:"actual abort"})')!
	failure := runtime.evaluate_host_value('({reason:"actual abort callback failure"})')!
	native_reason := runtime.webidl_value(reason)!
	native_failure := runtime.webidl_value(failure)!
	mut jobs := &NativeWritableRejectionJobs{}
	realm := jobs.realm()
	mut abort := webidl.create_promise_for(realm.promise_context())
	mut stream := streams.WritableStream.create(realm, streams.UnderlyingSink{
		abort_callback: webidl.CallbackType{
			callback: fn [mut jobs, abort] (_ webidl.Value, args []webidl.Value) !webidl.Value {
				jobs.seen = args[0]
				return webidl.promise_value(abort)
			}
		}
	}, streams.QueuingStrategy{})!
	jobs.drain()
	mut writer := stream.get_writer()!
	aborted := writer.abort(streams.runtime_value(native_reason))
	assert runtime.actual_webidl_value(jobs.seen or { panic('missing actual abort callback reason') })! == reason
	assert aborted.state() == .pending
	abort.reject(native_failure)
	jobs.drain()
	assert native_writable_rejection(runtime, aborted.as_webidl_promise())! == failure
	assert native_writable_rejection(runtime, writer.closed().as_webidl_promise())! == reason
}

fn test_in_flight_close_failure_rejects_close_and_pending_abort_with_actual_close_reason() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reason := runtime.evaluate_host_value('({reason:"actual pending close failure"})')!
	abort_reason := runtime.evaluate_host_value('({reason:"actual concurrent abort"})')!
	native_reason := runtime.webidl_value(reason)!
	native_abort_reason := runtime.webidl_value(abort_reason)!
	mut jobs := &NativeWritableRejectionJobs{}
	realm := jobs.realm()
	mut close := webidl.create_promise_for(realm.promise_context())
	mut stream := streams.WritableStream.create(realm, streams.UnderlyingSink{
		close_promise: fn [close] () !&webidl.Promise { return close }
	}, streams.QueuingStrategy{})!
	jobs.drain()
	mut writer := stream.get_writer()!
	closed := writer.close()
	aborted := writer.abort(streams.runtime_value(native_abort_reason))
	close.reject(native_reason)
	jobs.drain()
	assert native_writable_rejection(runtime, closed.as_webidl_promise())! == reason
	assert native_writable_rejection(runtime, aborted.as_webidl_promise())! == reason
	assert native_writable_rejection(runtime, writer.closed().as_webidl_promise())! == abort_reason
}
