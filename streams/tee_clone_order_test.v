module streams

import webidl

@[heap]
struct TeeCloneJobs {
mut:
	jobs []fn ()
	calls int
	first &ReadPromise = unsafe { nil }
	second &ReadPromise = unsafe { nil }
	reader1 &ReadableStreamDefaultReader = unsafe { nil }
	reader2 &ReadableStreamDefaultReader = unsafe { nil }
	cancel_reason ?webidl.Value
}

fn (mut jobs TeeCloneJobs) realm() StreamRealm {
	return StreamRealm.create_with_promise_context(webidl.PromiseContext{
		realm_id: 995
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	})
}

fn (mut jobs TeeCloneJobs) drain() {
	mut count := 0
	for jobs.jobs.len > 0 {
		count++
		assert count < 200
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn test_tee_clones_before_fulfilling_either_branch_read() {
	mut jobs := &TeeCloneJobs{}
	realm := jobs.realm().with_structured_clone_algorithm(fn [mut jobs] (value Value) !Value {
		assert jobs.first.state() == .pending && jobs.second.state() == .pending
		jobs.calls++
		return value.clone()
	})
	mut source := ReadableStream.create(realm, UnderlyingSource{}, QueuingStrategy{high_water_mark: 0})!
	pair := source.tee()!
	mut first := pair.first
	mut second := pair.second
	mut reader1 := first.get_default_reader()!
	mut reader2 := second.get_default_reader()!
	jobs.first = reader1.read()
	jobs.second = reader2.read()
	jobs.drain()
	source.enqueue(bytes_value([u8(1), 2]))!
	assert jobs.first.state() == .pending && jobs.second.state() == .pending
	jobs.drain()
	assert jobs.calls == 1 && jobs.first.state() == .fulfilled && jobs.second.state() == .fulfilled
	mut original := jobs.first.result().value
	original.bytes_[0] = 9
	assert jobs.second.result().value.bytes_ == [u8(1), 2]
}

fn test_tee_clone_failure_errors_both_reads_and_adopts_pending_source_cancellation() {
	for rejects in [false, true] {
		mut jobs := &TeeCloneJobs{}
		clone_error := webidl.dom_exception_value_for_record(webidl.DOMException.create_record('DataCloneError', 'actual clone completion'))
		later := webidl.dom_exception_value_for_record(webidl.DOMException.create_record('OperationError', 'later cancellation completion'))
		realm := jobs.realm().with_structured_clone_algorithm(fn [mut jobs, clone_error] (_ Value) !Value {
			assert jobs.first.state() == .pending && jobs.second.state() == .pending
			return webidl.throw_value(clone_error)
		})
		mut cancellation := webidl.create_promise_for(realm.promise_context())
		mut source := ReadableStream.create(realm, UnderlyingSource{
			cancel_promise: fn [mut jobs, cancellation] (reason Value) !&webidl.Promise {
				jobs.cancel_reason = stream_value_to_webidl(reason)
				return cancellation
			}
		}, QueuingStrategy{high_water_mark: 0})!
		pair := source.tee()!
		mut first := pair.first
		mut second := pair.second
		mut reader1 := first.get_default_reader()!
		mut reader2 := second.get_default_reader()!
		jobs.first = reader1.read()
		jobs.second = reader2.read()
		jobs.drain()
		source.enqueue(string_value('unclonable source chunk'))!
		jobs.drain()
		assert jobs.first.state() == .rejected && jobs.second.state() == .rejected
		assert jobs.first.as_webidl_promise().result.opaque_id == clone_error.opaque_id
		assert jobs.second.as_webidl_promise().result.opaque_id == clone_error.opaque_id
		assert (jobs.cancel_reason or { panic('missing source cancellation reason') }).opaque_id == clone_error.opaque_id
		assert first.tee_cancel_promise_.state() == .pending && second.tee_cancel_promise_.state() == .pending
		if rejects { cancellation.reject(later) } else { cancellation.resolve(webidl.undefined_value()) }
		jobs.drain()
		assert first.tee_cancel_promise_.state() == if rejects { PromiseState.rejected } else { PromiseState.fulfilled }
		if rejects { assert first.tee_cancel_promise_.as_webidl_promise().result.opaque_id == later.opaque_id }
	}
}

fn test_tee_skips_clone_when_second_branch_was_cancelled() {
	mut jobs := &TeeCloneJobs{}
	realm := jobs.realm().with_structured_clone_algorithm(fn (_ Value) !Value { assert false; return error('cancelled branch must not clone') })
	mut source := ReadableStream.create(realm, UnderlyingSource{}, QueuingStrategy{high_water_mark: 0})!
	pair := source.tee()!
	mut first := pair.first
	mut second := pair.second
	_ := second.cancel(string_value('second cancelled'))
	mut reader := first.get_default_reader()!
	read := reader.read()
	jobs.drain()
	source.enqueue(string_value('original'))!
	jobs.drain()
	assert read.state() == .fulfilled && read.result().value.text == 'original'
}

fn test_owning_clone_boundary_rejects_opaque_values_without_fabricating_an_alias() {
	actual := webidl.runtime_value(webidl.RuntimeValue{string_conversion: fn () !string { return error('must not stringify') }})
	for value in [runtime_value(actual), array_value([array_value([runtime_value(actual)])])] {
		if _ := structured_clone_in(StreamRealm{}, value) { assert false } else {
			failure := webidl.exception_value(err)
			exception := failure.dom_exception_ or { panic('missing typed unsupported clone boundary') }
			assert exception.name() == 'DataCloneError'
		}
	}
}

fn test_clone_reentrant_branch_cancellation_preserves_the_first_pending_resolve() {
	mut jobs := &TeeCloneJobs{}
	clone_error := webidl.dom_exception_value_for_record(webidl.DOMException.create_record('DataCloneError', 'reentrant clone failure'))
	realm := jobs.realm().with_structured_clone_algorithm(fn [mut jobs, clone_error] (_ Value) !Value {
		_ := jobs.reader1.cancel(string_value('first during clone'))
		_ := jobs.reader2.cancel(string_value('second during clone'))
		return webidl.throw_value(clone_error)
	})
	mut cancellation := webidl.create_promise_for(realm.promise_context())
	mut source := ReadableStream.create(realm, UnderlyingSource{
		cancel_promise: fn [cancellation] (reason Value) !&webidl.Promise {
			assert reason.items.len == 2
			assert reason.items[0].text == 'first during clone'
			assert reason.items[1].text == 'second during clone'
			return cancellation
		}
	}, QueuingStrategy{high_water_mark: 0})!
	pair := source.tee()!
	mut first := pair.first
	mut second := pair.second
	jobs.reader1 = first.get_default_reader()!
	jobs.reader2 = second.get_default_reader()!
	jobs.first = jobs.reader1.read()
	jobs.second = jobs.reader2.read()
	jobs.drain()
	source.enqueue(string_value('chunk enters structured clone'))!
	jobs.drain()
	assert first.tee_cancel_promise_.state() == .pending
	assert jobs.first.result().done && jobs.second.result().done
	first_resolution_failure := webidl.string_value('first adopted source cancellation')
	cancellation.reject(first_resolution_failure)
	jobs.drain()
	assert first.tee_cancel_promise_.state() == .rejected
	assert first.tee_cancel_promise_.as_webidl_promise().result.string_value == first_resolution_failure.string_value
}
