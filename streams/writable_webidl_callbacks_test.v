module streams

import webidl

@[heap]
struct WritableIDLJobs {
mut:
	jobs []fn ()
	controllers []u64
	calls []string
}

fn (mut jobs WritableIDLJobs) realm(id u64) StreamRealm {
	return StreamRealm.create_with_promise_context(webidl.PromiseContext{
		realm_id: id
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	})
}

fn (mut jobs WritableIDLJobs) drain() {
	mut count := 0
	for jobs.jobs.len > 0 {
		count++
		assert count < 100
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn test_writable_webidl_callbacks_retain_start_write_close_and_actual_controller_identity() {
	mut jobs := &WritableIDLJobs{}
	realm := jobs.realm(861)
	mut start := webidl.create_promise_for(realm.promise_context())
	mut write := webidl.create_promise_for(realm.promise_context())
	mut close := webidl.create_promise_for(realm.promise_context())
	mut stream := WritableStream.create(realm, UnderlyingSink{
		underlying_sink_value: webidl.string_value('actual sink')
		start_callback: webidl.CallbackType{
			callback: fn [mut jobs, start] (receiver webidl.Value, args []webidl.Value) !webidl.Value {
				assert receiver.string_value == 'actual sink'
				assert args.len == 1
				assert args[0].platform_interfaces == ['WritableStreamDefaultController']
				jobs.controllers << args[0].opaque_id
				return webidl.promise_value(start)
			}
		}
		write_callback: webidl.CallbackType{
			callback: fn [mut jobs, write] (receiver webidl.Value, args []webidl.Value) !webidl.Value {
				assert receiver.string_value == 'actual sink'
				assert args.len == 2
				assert args[1].platform_interfaces == ['WritableStreamDefaultController']
				jobs.controllers << args[1].opaque_id
				jobs.calls << args[0].string_value
				return webidl.promise_value(write)
			}
		}
		close_callback: webidl.CallbackType{
			callback: fn [mut jobs, close] (receiver webidl.Value, args []webidl.Value) !webidl.Value {
				assert receiver.string_value == 'actual sink'
				assert args.len == 0
				jobs.calls << 'close'
				return webidl.promise_value(close)
			}
		}
	}, QueuingStrategy{}) or { panic(err) }
	mut writer := stream.get_writer() or { panic(err) }
	written := writer.write(string_value('actual chunk'))
	closed := writer.close()
	jobs.drain()
	assert !stream.controller().started()
	assert jobs.calls.len == 0
	start.resolve(webidl.undefined_value())
	jobs.drain()
	assert jobs.controllers == [u64(voidptr(stream.controller())), u64(voidptr(stream.controller()))]
	assert jobs.calls == ['actual chunk']
	assert written.state() == .pending && closed.state() == .pending
	write.resolve(webidl.undefined_value())
	jobs.drain()
	assert jobs.calls == ['actual chunk', 'close']
	assert written.state() == .fulfilled
	assert closed.state() == .pending
	close.resolve(webidl.undefined_value())
	jobs.drain()
	assert stream.state() == .closed
	assert closed.state() == .fulfilled
}

fn test_writable_webidl_abort_callback_preserves_reason_and_its_own_realm_rejection() {
	mut owner_jobs := &WritableIDLJobs{}
	mut callback_jobs := &WritableIDLJobs{}
	realm := owner_jobs.realm(862)
	callback_realm := callback_jobs.realm(863)
	mut pending := webidl.create_promise_for(callback_realm.promise_context())
	mut stream := WritableStream.create(realm, UnderlyingSink{
		underlying_sink_value: webidl.number_value(19)
		abort_callback: webidl.CallbackType{
			promise_context: callback_realm.promise_context()
			callback: fn [mut callback_jobs, pending] (receiver webidl.Value, args []webidl.Value) !webidl.Value {
				assert receiver.number_value == 19
				assert args.len == 1
				assert args[0].kind == .sequence
				assert args[0].sequence_value[0].string_value == 'abort reason'
				assert args[0].sequence_value[1].number_value == 9
				callback_jobs.calls << 'abort'
				return webidl.promise_value(pending)
			}
		}
	}, QueuingStrategy{}) or { panic(err) }
	mut writer := stream.get_writer() or { panic(err) }
	owner_jobs.drain()
	result := writer.abort(array_value([string_value('abort reason'), number_value(9)]))
	assert callback_jobs.calls == ['abort']
	assert result.state() == .pending
	pending.reject(webidl.string_value('sink rejected abort'))
	owner_jobs.drain()
	assert result.state() == .pending
	callback_jobs.drain()
	owner_jobs.drain()
	assert result.reason() == 'sink rejected abort'
	assert stream.promise_abort_algorithm_ == none
}

fn test_writable_webidl_start_throws_synchronously_and_write_throw_errors_actual_stream() {
	mut jobs := &WritableIDLJobs{}
	realm := jobs.realm(864)
	if _ := WritableStream.create(realm, UnderlyingSink{
		start_callback: webidl.CallbackType{
			callback: fn (_ webidl.Value, _ []webidl.Value) !webidl.Value { return error('sink start exception') }
		}
	}, QueuingStrategy{}) { assert false } else { assert err.msg() == 'sink start exception' }
	mut stream := WritableStream.create(realm, UnderlyingSink{
		write_callback: webidl.CallbackType{
			callback: fn (_ webidl.Value, _ []webidl.Value) !webidl.Value { return error('sink write exception') }
		}
	}, QueuingStrategy{}) or { panic(err) }
	mut writer := stream.get_writer() or { panic(err) }
	result := writer.write(number_value(1))
	assert result.state() == .pending
	jobs.drain()
	assert stream.state() == .errored
	assert result.reason() == 'sink write exception'
}
