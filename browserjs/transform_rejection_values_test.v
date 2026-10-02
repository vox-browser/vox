module browserjs

import streams
import webidl

@[heap]
struct NativeTransformRejectionJobs {
mut:
	jobs []fn ()
	seen ?webidl.Value
}

fn (mut jobs NativeTransformRejectionJobs) realm() streams.StreamRealm {
	return streams.StreamRealm.create_with_promise_context(webidl.PromiseContext{
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	})
}

fn (mut jobs NativeTransformRejectionJobs) drain() {
	mut count := 0
	for jobs.jobs.len > 0 {
		count++
		assert count < 200
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn native_transform_rejection(runtime &Runtime, promise &webidl.Promise) !voidptr {
	assert promise.state == .rejected
	return runtime.actual_webidl_value(promise.result)
}

fn test_pending_transform_rethrows_original_actual_jsc_value_into_both_streams() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reason := runtime.evaluate_host_value('globalThis.transformReasonCoercions=0;({toString(){transformReasonCoercions++;throw new Error("must not coerce")}})')!
	native_reason := runtime.webidl_value(reason)!
	mut jobs := &NativeTransformRejectionJobs{}
	realm := jobs.realm()
	mut transformed := webidl.create_promise_for(realm.promise_context())
	stream := streams.TransformStream.create(realm, streams.Transformer{
		transform_promise: fn [transformed] (_ streams.Value) !&webidl.Promise { return transformed }
	}, streams.QueuingStrategy{}, streams.QueuingStrategy{})!
	mut writable := stream.writable()
	mut readable := stream.readable()
	mut writer := writable.get_writer()!
	mut reader := readable.get_default_reader()!
	written := writer.write(streams.undefined_value())
	read := reader.read()
	jobs.drain()
	transformed.reject(native_reason)
	assert read.state() == .pending
	assert written.state() == .pending
	jobs.drain()
	assert native_transform_rejection(runtime, read.as_webidl_promise())! == reason
	assert native_transform_rejection(runtime, written.as_webidl_promise())! == reason
	assert native_transform_rejection(runtime, writer.closed().as_webidl_promise())! == reason
	assert native_transform_rejection(runtime, reader.closed().as_webidl_promise())! == reason
	assert runtime.evaluate_host('transformReasonCoercions')! == '0'
}

fn test_pending_transform_flush_rejection_keeps_actual_symbol_for_finish_and_readers() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reason := runtime.evaluate_host_value('Symbol("actual flush rejection")')!
	native_reason := runtime.webidl_value(reason)!
	mut jobs := &NativeTransformRejectionJobs{}
	realm := jobs.realm()
	mut flush := webidl.create_promise_for(realm.promise_context())
	stream := streams.TransformStream.create(realm, streams.Transformer{
		flush_promise: fn [flush] () !&webidl.Promise { return flush }
	}, streams.QueuingStrategy{}, streams.QueuingStrategy{})!
	mut writable := stream.writable()
	mut readable := stream.readable()
	mut writer := writable.get_writer()!
	mut reader := readable.get_default_reader()!
	jobs.drain()
	read := reader.read()
	closed := writer.close()
	flush.reject(native_reason)
	assert closed.state() == .pending
	jobs.drain()
	assert native_transform_rejection(runtime, closed.as_webidl_promise())! == reason
	assert native_transform_rejection(runtime, read.as_webidl_promise())! == reason
	assert native_transform_rejection(runtime, reader.closed().as_webidl_promise())! == reason
}

fn test_pending_readable_cancel_retains_actual_argument_and_rejection_for_finish_and_writable() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reason := runtime.evaluate_host_value('({reason:"actual transform cancellation"})')!
	failure := runtime.evaluate_host_value('({reason:"actual transformer cancel failure"})')!
	native_reason := runtime.webidl_value(reason)!
	native_failure := runtime.webidl_value(failure)!
	mut jobs := &NativeTransformRejectionJobs{}
	realm := jobs.realm()
	mut cancel := webidl.create_promise_for(realm.promise_context())
	stream := streams.TransformStream.create(realm, streams.Transformer{
		cancel_callback: webidl.CallbackType{
			callback: fn [mut jobs, cancel] (_ webidl.Value, args []webidl.Value) !webidl.Value {
				jobs.seen = args[0]
				return webidl.promise_value(cancel)
			}
		}
	}, streams.QueuingStrategy{}, streams.QueuingStrategy{})!
	mut writable := stream.writable()
	mut readable := stream.readable()
	mut writer := writable.get_writer()!
	jobs.drain()
	cancelled := readable.cancel(streams.runtime_value(native_reason))
	assert runtime.actual_webidl_value(jobs.seen or { panic('missing actual cancel argument') })! == reason
	cancel.reject(native_failure)
	jobs.drain()
	assert native_transform_rejection(runtime, cancelled.as_webidl_promise())! == failure
	assert native_transform_rejection(runtime, writer.closed().as_webidl_promise())! == failure
}

fn test_transform_enqueue_size_throw_keeps_actual_completion_and_checks_real_readable_state() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reason := runtime.evaluate_host_value('({reason:"actual readable size callback throw"})')!
	native_reason := runtime.webidl_value(reason)!
	mut jobs := &NativeTransformRejectionJobs{}
	realm := jobs.realm()
	mut stream := streams.TransformStream.create(realm, streams.Transformer{}, streams.QueuingStrategy{}, streams.QueuingStrategy{
		size: fn [native_reason] (_ streams.Value) !f64 { return webidl.throw_value(native_reason) }
	})!
	mut writable := stream.writable()
	mut readable := stream.readable()
	mut writer := writable.get_writer()!
	mut reader := readable.get_default_reader()!
	jobs.drain()
	mut controller := stream.controller()
	if _ := controller.enqueue(streams.undefined_value()) { assert false }
	else {
		assert err is webidl.ValueException
		assert runtime.actual_webidl_value(webidl.exception_value(err))! == reason
	}
	jobs.drain()
	assert native_transform_rejection(runtime, writer.closed().as_webidl_promise())! == reason
	assert native_transform_rejection(runtime, reader.closed().as_webidl_promise())! == reason
	assert native_transform_rejection(runtime, reader.read().as_webidl_promise())! == reason
	mut empty_error := streams.TransformStream.create(realm, streams.Transformer{}, streams.QueuingStrategy{}, streams.QueuingStrategy{})!
	jobs.drain()
	empty_error.error('')
	mut empty_controller := empty_error.controller()
	if _ := empty_controller.enqueue(streams.undefined_value()) { assert false }
	else { assert err.msg().starts_with('TypeError:') }
}
