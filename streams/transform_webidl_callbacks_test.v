module streams

import webidl

@[heap]
struct TransformIDLJobs {
mut:
	jobs []fn ()
	controllers []u64
	calls []string
}

fn (mut jobs TransformIDLJobs) realm(id u64) StreamRealm {
	return StreamRealm.create_with_promise_context(webidl.PromiseContext{
		realm_id: id
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	})
}

fn (mut jobs TransformIDLJobs) drain() {
	mut count := 0
	for jobs.jobs.len > 0 {
		count++
		assert count < 200
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn test_transform_webidl_callbacks_use_actual_controller_and_shared_start_then_pending_flush() {
	mut jobs := &TransformIDLJobs{}
	realm := jobs.realm(871)
	mut start := webidl.create_promise_for(realm.promise_context())
	mut transformed := webidl.create_promise_for(realm.promise_context())
	mut flush := webidl.create_promise_for(realm.promise_context())
	stream := TransformStream.create(realm, Transformer{
		transformer_value: webidl.string_value('actual transformer')
		start_callback: webidl.CallbackType{
			callback: fn [mut jobs, start] (receiver webidl.Value, args []webidl.Value) !webidl.Value {
				assert receiver.string_value == 'actual transformer'
				assert args.len == 1
				assert args[0].platform_interfaces == ['TransformStreamDefaultController']
				jobs.controllers << args[0].opaque_id
				return webidl.promise_value(start)
			}
		}
		transform_callback: webidl.CallbackType{
			callback: fn [mut jobs, transformed] (receiver webidl.Value, args []webidl.Value) !webidl.Value {
				assert receiver.string_value == 'actual transformer'
				assert args.len == 2
				jobs.controllers << args[1].opaque_id
				jobs.calls << args[0].string_value
				mut controller := unsafe { &TransformStreamDefaultController(voidptr(args[1].opaque_id)) }
				controller.enqueue(string_value('actual transformed output'))!
				return webidl.promise_value(transformed)
			}
		}
		flush_callback: webidl.CallbackType{
			callback: fn [mut jobs, flush] (receiver webidl.Value, args []webidl.Value) !webidl.Value {
				assert receiver.string_value == 'actual transformer'
				assert args.len == 1
				jobs.controllers << args[0].opaque_id
				jobs.calls << 'flush'
				mut controller := unsafe { &TransformStreamDefaultController(voidptr(args[0].opaque_id)) }
				controller.enqueue(string_value('actual flush output'))!
				return webidl.promise_value(flush)
			}
		}
	}, QueuingStrategy{}, QueuingStrategy{}) or { panic(err) }
	mut readable := stream.readable()
	mut writable := stream.writable()
	mut reader := readable.get_default_reader() or { panic(err) }
	mut writer := writable.get_writer() or { panic(err) }
	written := writer.write(string_value('actual input'))
	first := reader.read()
	jobs.drain()
	assert !readable.default_controller_.started()
	assert !writable.controller().started()
	assert jobs.calls.len == 0
	start.resolve(webidl.undefined_value())
	jobs.drain()
	assert first.result().value.text == 'actual transformed output'
	assert written.state() == .pending
	transformed.resolve(webidl.undefined_value())
	jobs.drain()
	assert written.state() == .fulfilled
	second := reader.read()
	closed := writer.close()
	jobs.drain()
	assert second.result().value.text == 'actual flush output'
	assert closed.state() == .pending
	assert jobs.calls == ['actual input', 'flush']
	assert jobs.controllers == [u64(voidptr(stream.controller())), u64(voidptr(stream.controller())), u64(voidptr(stream.controller()))]
	flush.resolve(webidl.undefined_value())
	jobs.drain()
	assert closed.state() == .fulfilled
	assert readable.state() == .closed
}

fn test_transform_webidl_cancel_receiver_reason_and_pending_rejection_error_both_sides() {
	mut jobs := &TransformIDLJobs{}
	realm := jobs.realm(872)
	mut cancel := webidl.create_promise_for(realm.promise_context())
	stream := TransformStream.create(realm, Transformer{
		transformer_value: webidl.number_value(24)
		cancel_callback: webidl.CallbackType{
			callback: fn [mut jobs, cancel] (receiver webidl.Value, args []webidl.Value) !webidl.Value {
				assert receiver.number_value == 24
				assert args.len == 1
				jobs.calls << args[0].string_value
				return webidl.promise_value(cancel)
			}
		}
	}, QueuingStrategy{}, QueuingStrategy{}) or { panic(err) }
	mut readable := stream.readable()
	jobs.drain()
	result := readable.cancel(string_value('actual cancel reason'))
	assert jobs.calls == ['actual cancel reason']
	assert result.state() == .pending
	cancel.reject(webidl.string_value('transformer cancel rejected'))
	jobs.drain()
	assert result.reason() == 'transformer cancel rejected'
	assert stream.writable().state() == .errored
	assert stream.writable().stored_error() == 'transformer cancel rejected'
}

fn test_transform_webidl_start_throws_synchronously_and_transform_throw_rejects_write() {
	mut jobs := &TransformIDLJobs{}
	realm := jobs.realm(873)
	if _ := TransformStream.create(realm, Transformer{
		start_callback: webidl.CallbackType{
			callback: fn (_ webidl.Value, _ []webidl.Value) !webidl.Value { return error('transform start exception') }
		}
	}, QueuingStrategy{}, QueuingStrategy{}) { assert false } else { assert err.msg() == 'transform start exception' }
	stream := TransformStream.create(realm, Transformer{
		transform_callback: webidl.CallbackType{
			callback: fn (_ webidl.Value, _ []webidl.Value) !webidl.Value { return error('transform callback exception') }
		}
	}, QueuingStrategy{}, QueuingStrategy{}) or { panic(err) }
	mut writable := stream.writable()
	mut readable := stream.readable()
	mut writer := writable.get_writer() or { panic(err) }
	mut reader := readable.get_default_reader() or { panic(err) }
	result := writer.write(number_value(1))
	_ := reader.read()
	jobs.drain()
	assert result.reason() == 'transform callback exception'
	assert writable.state() == .errored
	assert readable.state() == .errored
}
