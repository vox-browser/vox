module streams

import webidl

@[heap]
struct NativeTeeReason {
	label string
}

@[heap]
struct TeeReasonJobs {
mut:
	jobs []fn ()
}

fn (mut jobs TeeReasonJobs) realm(id u64) StreamRealm {
	return StreamRealm.create_with_promise_context(webidl.PromiseContext{
		realm_id: id
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	})
}

fn (mut jobs TeeReasonJobs) drain() {
	mut count := 0
	for jobs.jobs.len > 0 {
		count++
		assert count < 200
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn test_tee_closed_reader_keeps_original_native_reason_for_default_and_byte_branches() {
	for type_ in [UnderlyingSourceType.default_source, .bytes] {
		mut jobs := &TeeReasonJobs{}
		realm := jobs.realm(975)
		mut source := ReadableStream.create(realm, UnderlyingSource{type_: type_}, QueuingStrategy{high_water_mark: 0})!
		pair := source.tee()!
		mut first := pair.first
		mut second := pair.second
		jobs.drain()
		mut cancelled := first.cancel(string_value('one branch only'))
		native := &NativeTeeReason{'actual native rejection'}
		reason := webidl.platform_object_value_with_id(u64(voidptr(native)))
		source.error_value(reason)
		assert cancelled.state() == .pending
		jobs.drain()
		assert second.state() == .errored
		assert second.stored_error_value().opaque_id == u64(voidptr(native))
		assert cancelled.state() == .fulfilled
		mut reader := second.get_default_reader()!
		read := reader.read()
		assert read.as_webidl_promise().result.opaque_id == u64(voidptr(native))
	}
}

fn test_tee_cancellation_adopts_arbitrary_pending_source_rejection_without_string_conversion() {
	for type_ in [UnderlyingSourceType.default_source, .bytes] {
		mut jobs := &TeeReasonJobs{}
		realm := jobs.realm(976)
		mut cancellation := webidl.create_promise_for(realm.promise_context())
		mut source := ReadableStream.create(realm, UnderlyingSource{
			type_: type_
			cancel_promise: fn [cancellation] (_ Value) !&webidl.Promise { return cancellation }
		}, QueuingStrategy{high_water_mark: 0})!
		pair := source.tee()!
		mut first := pair.first
		mut second := pair.second
		jobs.drain()
		a := first.cancel(string_value('first'))
		b := second.cancel(string_value('second'))
		assert a.state() == .pending && b.state() == .pending
		native := &NativeTeeReason{'pending source cancellation'}
		cancellation.reject(webidl.platform_object_value_with_id(u64(voidptr(native))))
		jobs.drain()
		assert a.state() == .rejected && b.state() == .rejected
		assert a.as_webidl_promise().result.opaque_id == u64(voidptr(native))
		assert b.as_webidl_promise().result.opaque_id == u64(voidptr(native))
	}
}
