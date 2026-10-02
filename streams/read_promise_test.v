module streams

import webidl

@[heap]
struct ReadPromiseJobs {
mut:
	jobs []fn ()
	values []webidl.Value
	reasons []string
}

fn (mut jobs ReadPromiseJobs) realm(id u64) StreamRealm {
	return StreamRealm.create_with_promise_context(webidl.PromiseContext{
		realm_id: id
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	})
}

fn (mut jobs ReadPromiseJobs) drain() {
	mut count := 0
	for jobs.jobs.len > 0 {
		count++
		assert count < 100
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn test_default_read_request_resolves_one_actual_native_promise_with_queued_result_observers() {
	mut jobs := &ReadPromiseJobs{}
	realm := jobs.realm(941)
	mut stream := ReadableStream.create(realm, UnderlyingSource{}, QueuingStrategy{ high_water_mark: 0 }) or { panic(err) }
	mut reader := stream.get_default_reader() or { panic(err) }
	read := reader.read()
	mut native := read.as_webidl_promise()
	assert voidptr(native) == voidptr(read.as_webidl_promise())
	assert webidl.promise_realm(native) == 941
	_ := native.upon_fulfillment(fn [mut jobs] (value webidl.Value) !webidl.Value {
		jobs.values << value
		return webidl.undefined_value()
	})
	_ := native.upon_fulfillment(fn [mut jobs] (value webidl.Value) !webidl.Value {
		jobs.values << value
		return webidl.undefined_value()
	})
	jobs.drain()
	stream.enqueue(string_value('source read chunk')) or { panic(err) }
	assert read.state() == .fulfilled
	assert native.state == .fulfilled
	assert jobs.values.len == 0
	jobs.drain()
	assert jobs.values.len == 2
	assert jobs.values[0].object_value['value'].string_value == 'source read chunk'
	assert jobs.values[0].object_value['done'].boolean_value == false
}

fn test_default_read_close_and_reader_release_settle_native_capabilities_with_source_values() {
	mut jobs := &ReadPromiseJobs{}
	realm := jobs.realm(942)
	mut stream := ReadableStream.create(realm, UnderlyingSource{}, QueuingStrategy{ high_water_mark: 0 }) or { panic(err) }
	mut reader := stream.get_default_reader() or { panic(err) }
	read := reader.read()
	mut native := read.as_webidl_promise()
	_ := native.upon_rejection(fn [mut jobs] (reason webidl.Value) !webidl.Value {
		jobs.reasons << reason.string_value
		return webidl.undefined_value()
	})
	reader.release_lock() or { panic(err) }
	assert native.state == .rejected
	assert jobs.reasons.len == 0
	jobs.drain()
	assert jobs.reasons == [read.reason()]
	mut replacement := stream.get_default_reader() or { panic(err) }
	closed := replacement.read()
	stream.close()
	close_native := closed.as_webidl_promise()
	assert close_native.state == .fulfilled
	assert close_native.result.object_value['done'].boolean_value
	assert close_native.result.object_value['value'].kind == .undefined
}

fn test_byob_read_request_retains_pending_native_capability_until_actual_minimum_fill() {
	mut jobs := &ReadPromiseJobs{}
	realm := jobs.realm(943)
	mut stream := ReadableStream.create(realm, UnderlyingSource{ type_: .bytes }, QueuingStrategy{}) or { panic(err) }
	mut reader := stream.get_byob_reader() or { panic(err) }
	read := reader.read(4, 2)
	mut native := read.as_webidl_promise()
	_ := native.upon_fulfillment(fn [mut jobs] (value webidl.Value) !webidl.Value {
		jobs.values << value
		return webidl.undefined_value()
	})
	jobs.drain()
	mut controller := stream.byte_controller() or { panic(err) }
	mut first := controller.byob_request() or { panic('missing BYOB source request') }
	first.write_view([u8(91)]) or { panic(err) }
	first.respond(1) or { panic(err) }
	assert native.state == .pending
	mut second := controller.byob_request() or { panic('missing partial source request') }
	second.write_view([u8(92)]) or { panic(err) }
	second.respond(1) or { panic(err) }
	assert native.state == .fulfilled
	assert jobs.values.len == 0
	jobs.drain()
	assert jobs.values.len == 1
	assert jobs.values[0].object_value['done'].boolean_value == false
	view := jobs.values[0].object_value['value'].buffer_value or { panic('missing actual typed buffer') }
	assert view.kind == .uint8_array
	assert view.byte_length() == 2
	assert read.result().value == [u8(91), 92]
	assert webidl.promise_realm(native) == 943
}

fn test_public_read_promise_literals_lazily_retain_actual_native_settlement_and_identity() {
	mut jobs := &ReadPromiseJobs{}
	realm := jobs.realm(944)
	mut read := &ReadPromise{ realm_: realm }
	mut byob := &BYOBReadPromise{ realm_: realm }
	read.resolve(number_value(42), false)
	byob.reject('source BYOB rejection')
	assert read.as_webidl_promise().state == .fulfilled
	assert read.as_webidl_promise().result.object_value['value'].number_value == 42
	assert byob.as_webidl_promise().state == .rejected
	assert byob.as_webidl_promise().result.string_value == 'source BYOB rejection'
	fulfilled := &ReadPromise{ state_: .fulfilled, result_: ReadResult{ done: true }, realm_: realm }
	assert fulfilled.as_webidl_promise().result.object_value['done'].boolean_value
	assert voidptr(fulfilled.as_webidl_promise()) == voidptr(fulfilled.as_webidl_promise())
	assert webidl.promise_realm(fulfilled.as_webidl_promise()) == 944
}
