module streams

import webidl

@[heap]
struct TeeCallbackJobs {
mut:
	jobs []fn ()
	reasons []string
}

fn (mut jobs TeeCallbackJobs) realm(id u64) StreamRealm {
	return StreamRealm.create_with_promise_context(webidl.PromiseContext{
		realm_id: id
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	})
}

fn (mut jobs TeeCallbackJobs) drain() {
	mut count := 0
	for jobs.jobs.len > 0 {
		count++
		assert count < 200
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn test_tee_branch_cancels_adopt_the_shared_pending_source_cancel_promise() {
	mut jobs := &TeeCallbackJobs{}
	realm := jobs.realm(741)
	mut cancel := webidl.create_promise_for(realm.promise_context())
	mut source := ReadableStream.create(realm, UnderlyingSource{
		cancel_promise: fn [mut jobs, cancel] (reason Value) !&webidl.Promise {
			for value in reason.items { jobs.reasons << value.text }
			return cancel
		}
	}, QueuingStrategy{ high_water_mark: 0 }) or { panic(err) }
	pair := source.tee() or { panic(err) }
	mut first := pair.first
	mut second := pair.second
	assert voidptr(first.tee_cancel_promise_) == voidptr(second.tee_cancel_promise_)
	jobs.drain()
	first_cancel := first.cancel(string_value('first'))
	second_cancel := second.cancel(string_value('second'))
	assert voidptr(first_cancel) != voidptr(second_cancel)
	assert first_cancel.state() == .pending && second_cancel.state() == .pending
	assert jobs.reasons == ['first', 'second']
	cancel.reject(webidl.string_value('source cancel failed'))
	assert first_cancel.state() == .pending
	jobs.drain()
	assert first_cancel.reason() == 'source cancel failed'
	assert second_cancel.reason() == 'source cancel failed'
}

fn test_tee_closed_reaction_ignores_distinct_replaced_reader_with_equal_promise_fields() {
	mut jobs := &TeeCallbackJobs{}
	realm := jobs.realm(746)
	mut source := ReadableStream.create(realm, UnderlyingSource{}, QueuingStrategy{ high_water_mark: 0 }) or { panic(err) }
	pair := source.tee() or { panic(err) }
	jobs.drain()
	stale_closed := VoidPromise.rejected_in(realm, 'equal reader rejection')
	current_closed := VoidPromise.rejected_in(realm, 'equal reader rejection')
	assert voidptr(stale_closed) != voidptr(current_closed)
	mut reader := source.default_reader_
	reader.closed_ = current_closed
	source.state_ = .errored
	observe_tee_reader_closed(mut source, stale_closed)
	jobs.drain()
	assert pair.first.state() == .readable
	assert pair.second.state() == .readable
}

fn test_byte_tee_cancels_wait_for_the_pending_source_cancel_to_fulfill() {
	mut jobs := &TeeCallbackJobs{}
	realm := jobs.realm(742)
	mut cancel := webidl.create_promise_for(realm.promise_context())
	mut source := ReadableStream.create(realm, UnderlyingSource{
		type_: .bytes
		cancel_promise: fn [cancel] (_ Value) !&webidl.Promise { return cancel }
	}, QueuingStrategy{}) or { panic(err) }
	pair := source.tee() or { panic(err) }
	mut first := pair.first
	mut second := pair.second
	jobs.drain()
	a := first.cancel(string_value('a'))
	b := second.cancel(string_value('b'))
	assert a.state() == .pending && b.state() == .pending
	cancel.resolve(webidl.undefined_value())
	jobs.drain()
	assert a.state() == .fulfilled && b.state() == .fulfilled
}

fn test_tee_default_chunk_delivery_runs_on_the_owner_microtask_queue() {
	mut jobs := &TeeCallbackJobs{}
	realm := jobs.realm(743)
	mut source := ReadableStream.create(realm, UnderlyingSource{}, QueuingStrategy{ high_water_mark: 0 }) or { panic(err) }
	pair := source.tee() or { panic(err) }
	mut first := pair.first
	mut second := pair.second
	mut reader1 := first.get_default_reader() or { panic(err) }
	mut reader2 := second.get_default_reader() or { panic(err) }
	a := reader1.read()
	b := reader2.read()
	jobs.drain()
	source.enqueue(string_value('queued tee chunk')) or { panic(err) }
	assert a.state() == .pending && b.state() == .pending
	assert source.tee_delivery_queued_
	jobs.drain()
	assert a.result().value.text == 'queued tee chunk'
	assert b.result().value.text == 'queued tee chunk'
}

fn test_byte_tee_byob_chunk_delivery_preserves_pending_reads_until_owner_microtask() {
	mut jobs := &TeeCallbackJobs{}
	realm := jobs.realm(744)
	mut source := ReadableStream.create(realm, UnderlyingSource{ type_: .bytes }, QueuingStrategy{}) or { panic(err) }
	pair := source.tee() or { panic(err) }
	mut first := pair.first
	mut second := pair.second
	mut reader1 := first.get_byob_reader() or { panic(err) }
	mut reader2 := second.get_default_reader() or { panic(err) }
	a := reader1.read(4, 1)
	b := reader2.read()
	jobs.drain()
	mut controller := source.byte_controller() or { panic(err) }
	mut request := controller.byob_request() or { panic('missing source BYOB view') }
	request.write_view([u8(71), 72]) or { panic(err) }
	request.respond(2) or { panic(err) }
	assert a.state() == .pending && b.state() == .pending
	jobs.drain()
	assert a.result().value == [u8(71), 72]
	assert b.result().value.bytes_ == [u8(71), 72]
}

fn test_tee_reader_closed_rejection_errors_branches_and_fulfills_single_cancel() {
	mut jobs := &TeeCallbackJobs{}
	realm := jobs.realm(745)
	mut source := ReadableStream.create(realm, UnderlyingSource{}, QueuingStrategy{ high_water_mark: 0 }) or { panic(err) }
	pair := source.tee() or { panic(err) }
	mut first := pair.first
	jobs.drain()
	cancelled := first.cancel(string_value('one branch only'))
	source.error('reader closed rejection')
	assert cancelled.state() == .pending
	jobs.drain()
	assert pair.second.state() == .errored
	assert pair.second.stored_error() == 'reader closed rejection'
	assert cancelled.state() == .fulfilled
}
