module streams

import webidl

@[heap]
struct ReadableIDLJobs {
mut:
	jobs []fn ()
	controllers []u64
	receivers []u64
	reasons []string
}

fn (mut jobs ReadableIDLJobs) realm(id u64) StreamRealm {
	return StreamRealm.create_with_promise_context(webidl.PromiseContext{
		realm_id: id
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	})
}

fn (mut jobs ReadableIDLJobs) drain() {
	mut count := 0
	for jobs.jobs.len > 0 {
		count++
		assert count < 100
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn test_readable_webidl_callbacks_receive_actual_controller_receiver_and_adopt_pending_values() {
	mut jobs := &ReadableIDLJobs{}
	realm := jobs.realm(851)
	mut start := webidl.create_promise_for(realm.promise_context())
	mut pull := webidl.create_promise_for(realm.promise_context())
	receiver := webidl.object_value_with_id(map[string]webidl.Value{}, u64(voidptr(jobs)))
	mut stream := ReadableStream.create(realm, underlying_source_from_bindings(BindingsUnderlyingSource{
		underlying_source_value: receiver
		start_callback: webidl.CallbackType{
			callback: fn [mut jobs, start] (this_value webidl.Value, args []webidl.Value) !webidl.Value {
				assert args.len == 1
				assert args[0].platform_interfaces == ['ReadableStreamDefaultController']
				jobs.controllers << args[0].opaque_id
				jobs.receivers << this_value.opaque_id
				return webidl.promise_value(start)
			}
		}
		pull_callback: webidl.CallbackType{
			callback: fn [mut jobs, pull] (this_value webidl.Value, args []webidl.Value) !webidl.Value {
				jobs.controllers << args[0].opaque_id
				jobs.receivers << this_value.opaque_id
				mut controller := unsafe { &ReadableStreamDefaultController(voidptr(args[0].opaque_id)) }
				controller.enqueue(string_value('actual callback chunk'))!
				return webidl.promise_value(pull)
			}
		}
	}), QueuingStrategy{ high_water_mark: 0 }) or { panic(err) }
	mut controller := stream.default_controller() or { panic(err) }
	mut reader := stream.get_default_reader() or { panic(err) }
	read := reader.read()
	jobs.drain()
	assert !controller.started()
	assert read.state() == .pending
	start.resolve(webidl.undefined_value())
	jobs.drain()
	assert read.result().value.text == 'actual callback chunk'
	assert controller.pulling()
	assert jobs.controllers == [u64(voidptr(controller)), u64(voidptr(controller))]
	assert jobs.receivers == [receiver.opaque_id, receiver.opaque_id]
	pull.resolve(webidl.undefined_value())
	jobs.drain()
	assert !controller.pulling()
}

fn test_readable_webidl_cancel_uses_callback_realm_and_retains_actual_pending_rejection() {
	mut owner_jobs := &ReadableIDLJobs{}
	mut callback_jobs := &ReadableIDLJobs{}
	realm := owner_jobs.realm(852)
	callback_realm := callback_jobs.realm(853)
	mut pending := webidl.create_promise_for(callback_realm.promise_context())
	mut stream := ReadableStream.create(realm, UnderlyingSource{
		underlying_source_value: webidl.string_value('source receiver')
		cancel_callback: webidl.CallbackType{
			promise_context: callback_realm.promise_context()
			callback: fn [mut callback_jobs, pending] (this_value webidl.Value, args []webidl.Value) !webidl.Value {
				assert this_value.string_value == 'source receiver'
				assert args.len == 1
				callback_jobs.reasons << args[0].string_value
				return webidl.promise_value(pending)
			}
		}
	}, QueuingStrategy{ high_water_mark: 0 }) or { panic(err) }
	owner_jobs.drain()
	result := stream.cancel(string_value('source cancel reason'))
	assert result.state() == .pending
	assert stream.state() == .closed
	assert callback_jobs.reasons == ['source cancel reason']
	assert callback_jobs.jobs.len == 1
	pending.reject(webidl.string_value('callback realm rejected'))
	owner_jobs.drain()
	assert result.state() == .pending
	callback_jobs.drain()
	owner_jobs.drain()
	assert result.reason() == 'callback realm rejected'
	assert webidl.promise_realm(result.as_webidl_promise()) == 852
}

fn test_byte_stream_webidl_pull_exposes_actual_byob_controller_and_pending_response() {
	mut jobs := &ReadableIDLJobs{}
	realm := jobs.realm(854)
	mut pending := webidl.create_promise_for(realm.promise_context())
	mut stream := ReadableStream.create(realm, UnderlyingSource{
		type_: .bytes
		pull_callback: webidl.CallbackType{
			callback: fn [mut jobs, pending] (_ webidl.Value, args []webidl.Value) !webidl.Value {
				assert args[0].platform_interfaces == ['ReadableByteStreamController']
				jobs.controllers << args[0].opaque_id
				mut controller := unsafe { &ReadableByteStreamController(voidptr(args[0].opaque_id)) }
				mut request := controller.byob_request() or { return error('missing source BYOB request') }
				request.write_view([u8(81), 82])!
				request.respond(2)!
				return webidl.promise_value(pending)
			}
		}
	}, QueuingStrategy{}) or { panic(err) }
	mut reader := stream.get_byob_reader() or { panic(err) }
	read := reader.read(4, 2)
	jobs.drain()
	controller := stream.byte_controller() or { panic(err) }
	assert jobs.controllers == [u64(voidptr(controller))]
	assert read.result().value == [u8(81), 82]
	assert controller.pulling()
	pending.resolve(webidl.undefined_value())
	jobs.drain()
	assert !controller.pulling()
}

fn test_readable_webidl_start_exception_is_synchronous_and_pull_exception_rejects_async() {
	mut jobs := &ReadableIDLJobs{}
	realm := jobs.realm(855)
	if _ := ReadableStream.create(realm, UnderlyingSource{
		start_callback: webidl.CallbackType{
			callback: fn (_ webidl.Value, _ []webidl.Value) !webidl.Value { return error('start exception') }
		}
	}, QueuingStrategy{}) { assert false } else { assert err.msg() == 'start exception' }
	mut stream := ReadableStream.create(realm, UnderlyingSource{
		pull_callback: webidl.CallbackType{
			callback: fn (_ webidl.Value, _ []webidl.Value) !webidl.Value { return error('pull exception') }
		}
	}, QueuingStrategy{ high_water_mark: 0 }) or { panic(err) }
	mut reader := stream.get_default_reader() or { panic(err) }
	read := reader.read()
	assert stream.state() == .readable
	jobs.drain()
	assert stream.state() == .errored
	assert read.reason() == 'pull exception'
}
