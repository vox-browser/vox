module streams

import webidl

@[heap]
struct AbruptCallbackJobs {
mut:
	jobs []fn ()
}

fn (mut jobs AbruptCallbackJobs) realm() StreamRealm {
	return StreamRealm.create_with_promise_context(webidl.PromiseContext{
		realm_id: 984
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	})
}

fn (mut jobs AbruptCallbackJobs) drain() {
	mut count := 0
	for jobs.jobs.len > 0 {
		count++
		assert count < 200
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn abrupt_callback_reason(label string) webidl.Value {
	return webidl.dom_exception_value_for_record(webidl.DOMException.create_record('OperationError', label))
}

fn assert_same_callback_reason(actual webidl.Value, original webidl.Value) {
	assert actual.kind == original.kind
	assert actual.opaque_id == original.opaque_id
	actual_record := actual.dom_exception_ or { panic('missing actual thrown record') }
	original_record := original.dom_exception_ or { panic('missing original thrown record') }
	assert voidptr(actual_record) == voidptr(original_record)
}

fn test_readable_native_pull_and_cancel_abrupt_completions_retain_actual_exception_record() {
	for promise_callback in [false, true] {
		mut jobs := &AbruptCallbackJobs{}
		realm := jobs.realm()
		pull_reason := abrupt_callback_reason('native pull completion')
		pull_source := if promise_callback {
			UnderlyingSource{pull_promise: fn [pull_reason] () !&webidl.Promise { return webidl.throw_value(pull_reason) }}
		} else {
			UnderlyingSource{pull: fn [pull_reason] () ! { return webidl.throw_value(pull_reason) }}
		}
		mut pulled := ReadableStream.create(realm, pull_source, QueuingStrategy{high_water_mark: 0})!
		mut reader := pulled.get_default_reader()!
		read := reader.read()
		assert read.as_webidl_promise().state == .pending
		jobs.drain()
		assert pulled.state() == .errored
		assert_same_callback_reason(read.as_webidl_promise().result, pull_reason)
		assert_same_callback_reason(reader.closed().as_webidl_promise().result, pull_reason)

		cancel_reason := abrupt_callback_reason('native cancel completion')
		cancel_source := if promise_callback {
			UnderlyingSource{cancel_promise: fn [cancel_reason] (_ Value) !&webidl.Promise { return webidl.throw_value(cancel_reason) }}
		} else {
			UnderlyingSource{cancel: fn [cancel_reason] (_ Value) ! { return webidl.throw_value(cancel_reason) }}
		}
		mut cancelled := ReadableStream.create(realm, cancel_source, QueuingStrategy{high_water_mark: 0})!
		jobs.drain()
		result := cancelled.cancel(undefined_value())
		assert result.state() == .pending
		jobs.drain()
		assert result.state() == .rejected
		assert_same_callback_reason(result.as_webidl_promise().result, cancel_reason)
	}
}

fn test_writable_native_write_close_and_abort_abrupt_completions_retain_actual_exception_record() {
	for promise_callback in [false, true] {
		for operation in ['write', 'close', 'abort'] {
			mut jobs := &AbruptCallbackJobs{}
			realm := jobs.realm()
			reason := abrupt_callback_reason('native ${operation} completion')
			sink := if promise_callback {
				UnderlyingSink{
					write_promise: fn [reason] (_ Value) !&webidl.Promise { return webidl.throw_value(reason) }
					close_promise: fn [reason] () !&webidl.Promise { return webidl.throw_value(reason) }
					abort_promise: fn [reason] (_ Value) !&webidl.Promise { return webidl.throw_value(reason) }
				}
			} else {
				UnderlyingSink{
					write: fn [reason] (_ Value) ! { return webidl.throw_value(reason) }
					close: fn [reason] () ! { return webidl.throw_value(reason) }
					abort: fn [reason] (_ Value) ! { return webidl.throw_value(reason) }
				}
			}
			mut stream := WritableStream.create(realm, sink, QueuingStrategy{})!
			mut writer := stream.get_writer()!
			jobs.drain()
			result := match operation {
				'write' { writer.write(string_value('chunk')) }
				'close' { writer.close() }
				else { writer.abort(string_value('requested abort')) }
			}
			assert result.state() == .pending
			jobs.drain()
			assert result.state() == .rejected
			assert_same_callback_reason(result.as_webidl_promise().result, reason)
			if operation != 'abort' {
				assert_same_callback_reason(stream.stored_error_value(), reason)
				assert_same_callback_reason(writer.closed().as_webidl_promise().result, reason)
			}
		}
	}
}

fn test_writable_size_abrupt_completion_errors_with_actual_value_before_write_is_enqueued() {
	mut jobs := &AbruptCallbackJobs{}
	realm := jobs.realm()
	reason := abrupt_callback_reason('strategy size completion')
	mut stream := WritableStream.create(realm, UnderlyingSink{}, QueuingStrategy{
		size: fn [reason] (_ Value) !f64 { return webidl.throw_value(reason) }
	})!
	mut writer := stream.get_writer()!
	jobs.drain()
	result := writer.write(string_value('never enqueued'))
	assert result.state() == .rejected
	assert stream.written_values().len == 0
	assert_same_callback_reason(result.as_webidl_promise().result, reason)
	assert_same_callback_reason(stream.stored_error_value(), reason)
	jobs.drain()
	assert_same_callback_reason(writer.closed().as_webidl_promise().result, reason)
}

fn test_transform_native_transform_flush_and_cancel_abrupt_completions_retain_actual_exception_record() {
	for promise_callback in [false, true] {
		for operation in ['transform', 'flush', 'cancel', 'abort'] {
			mut jobs := &AbruptCallbackJobs{}
			realm := jobs.realm()
			reason := abrupt_callback_reason('native transformer ${operation} completion')
			transformer := if promise_callback {
				Transformer{
					transform_promise: fn [reason] (_ Value) !&webidl.Promise { return webidl.throw_value(reason) }
					flush_promise: fn [reason] () !&webidl.Promise { return webidl.throw_value(reason) }
					cancel_promise: fn [reason] (_ Value) !&webidl.Promise { return webidl.throw_value(reason) }
				}
			} else {
				Transformer{
					transform: fn [reason] (_ Value) ![]Value { return webidl.throw_value(reason) }
					flush: fn [reason] () ![]Value { return webidl.throw_value(reason) }
					cancel: fn [reason] (_ Value) ! { return webidl.throw_value(reason) }
				}
			}
			mut stream := TransformStream.create(realm, transformer, QueuingStrategy{}, QueuingStrategy{})!
			mut writable := stream.writable()
			mut readable := stream.readable()
			mut writer := writable.get_writer()!
			jobs.drain()
			mut read := &ReadPromise{}
			result := match operation {
				'transform' {
					mut reader := readable.get_default_reader()!
					read = reader.read()
					writer.write(string_value('chunk'))
				}
				'flush' { writer.close() }
				'cancel' { readable.cancel(string_value('requested cancel')) }
				else { writer.abort(string_value('requested abort')) }
			}
			assert result.state() == .pending
			jobs.drain()
			assert result.state() == .rejected
			assert_same_callback_reason(result.as_webidl_promise().result, reason)
			if operation == 'transform' {
				assert_same_callback_reason(read.as_webidl_promise().result, reason)
				assert_same_callback_reason(writable.stored_error_value(), reason)
			}
			if operation != 'cancel' {
				assert_same_callback_reason(readable.stored_error_value(), reason)
			} else {
				assert_same_callback_reason(writable.stored_error_value(), reason)
			}
		}
	}
}
