// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module streams

import webidl

@[heap]
struct VoidAdoptionJobs {
mut:
	jobs []fn ()
}

fn (mut jobs VoidAdoptionJobs) realm() StreamRealm {
	return StreamRealm.create_with_promise_context(webidl.PromiseContext{
		realm_id: 996
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	})
}

fn (mut jobs VoidAdoptionJobs) drain() {
	mut count := 0
	for jobs.jobs.len > 0 {
		count++
		assert count < 100
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn test_void_promise_resolution_adopts_once_with_original_identity_and_owner_jobs() {
	for rejects in [false, true] {
		mut jobs := &VoidAdoptionJobs{}
		realm := jobs.realm()
		// Public heap construction retains the lazy actual capability contract.
		mut capability := &VoidPromise{realm_: realm}
		native := capability.as_webidl_promise()
		mut pending := webidl.create_promise_for(realm.promise_context())
		reason := webidl.dom_exception_value_for_record(webidl.DOMException.create_record('OperationError', 'first resolution'))
		capability.resolve_with_promise(pending)
		assert voidptr(capability.as_webidl_promise()) == voidptr(native)
		capability.resolve()
		capability.reject('later rejection must not win')
		capability.resolve_with_promise(webidl.create_resolved_promise(webidl.undefined_value()))
		jobs.drain()
		assert capability.state() == .pending && native.state == .pending
		if rejects { pending.reject(reason) } else { pending.resolve(webidl.undefined_value()) }
		assert capability.state() == .pending
		jobs.drain()
		assert capability.state() == if rejects { PromiseState.rejected } else { PromiseState.fulfilled }
		if rejects {
			assert native.result.opaque_id == reason.opaque_id
			assert capability.reason() == callback_reason(reason)
		}
	}
}

fn test_void_promise_self_adoption_rejects_the_actual_capability() {
	mut capability := &VoidPromise{}
	capability.resolve_with_promise(capability.as_webidl_promise())
	assert capability.state() == .rejected
	assert capability.reason() == 'TypeError: Cannot resolve promise with itself'
	capability.resolve()
	assert capability.state() == .rejected
}

fn test_shared_tee_cancellation_cannot_be_fulfilled_again_while_source_cancel_is_pending() {
	mut jobs := &VoidAdoptionJobs{}
	realm := jobs.realm()
	mut pending := webidl.create_promise_for(realm.promise_context())
	mut source := ReadableStream.create(realm, UnderlyingSource{
		cancel_promise: fn [pending] (_ Value) !&webidl.Promise { return pending }
	}, QueuingStrategy{high_water_mark: 0})!
	pair := source.tee()!
	mut first := pair.first
	mut second := pair.second
	_ := first.cancel(string_value('first'))
	_ := second.cancel(string_value('second'))
	capability := first.tee_cancel_promise_
	assert voidptr(capability) == voidptr(second.tee_cancel_promise_)
	// A later source resolution, including a clone-failure or close path, must
	// preserve the first Resolve call's pending adoption.
	settle_tee_cancel_promises(mut source, none)
	adopt_tee_cancel_result(mut source, VoidPromise.fulfilled_in(realm))
	jobs.drain()
	assert capability.state() == .pending
	actual_reason := webidl.string_value('original pending cancellation failed')
	pending.reject(actual_reason)
	jobs.drain()
	assert capability.state() == .rejected
	assert capability.as_webidl_promise().result.string_value == actual_reason.string_value
}
