// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// The Promise-returning side of the typed WebIDL callback boundary. Existing
// native void callbacks are converted to resolved/rejected WebIDL promises;
// callbacks supplied by a runtime retain their actual pending Promise.
module streams

import webidl

pub type PromiseStartAlgorithm = fn () !&webidl.Promise
pub type PromisePullAlgorithm = fn () !&webidl.Promise
pub type PromiseCancelAlgorithm = fn (Value) !&webidl.Promise
pub type PromiseWriteAlgorithm = fn (Value) !&webidl.Promise
pub type PromiseCloseAlgorithm = fn () !&webidl.Promise
pub type PromiseAbortAlgorithm = fn (Value) !&webidl.Promise
pub type PromiseTransformAlgorithm = fn (Value) !&webidl.Promise
pub type PromiseFlushAlgorithm = fn () !&webidl.Promise

fn resolved_callback_promise(realm StreamRealm) &webidl.Promise {
	return webidl.create_resolved_promise_for(realm.promise_context(), webidl.undefined_value())
}

fn rejected_callback_promise(realm StreamRealm, reason string) &webidl.Promise {
	return webidl.create_rejected_promise_for(realm.promise_context(), webidl.string_value(reason))
}

fn callback_reason(reason webidl.Value) string {
	return webidl.to_string(reason) or { 'TypeError: Cannot convert callback rejection reason' }
}

fn void_promise_from_webidl(realm StreamRealm, mut native webidl.Promise) &VoidPromise {
	mut result := VoidPromise.pending_in(realm)
	webidl.react_to_promise(mut native, fn [mut result] (_ webidl.Value) !webidl.Value {
		result.resolve()
		return webidl.undefined_value()
	}, fn [mut result] (reason webidl.Value) !webidl.Value {
		result.reject(callback_reason(reason))
		return webidl.undefined_value()
	})
	return result
}

fn (mut stream ReadableStream) invoke_pull_algorithm() &webidl.Promise {
	if stream.owner_kind_ == .transform {
		mut transform := unsafe { &TransformStream(stream.owner_) }
		return transform_stream_default_source_pull_algorithm(mut transform).as_webidl_promise()
	}
	if algorithm := stream.promise_pull_algorithm_ {
		return algorithm() or { rejected_callback_promise(stream.realm_, err.msg()) }
	}
	if algorithm := stream.pull_algorithm_ {
		algorithm() or { return rejected_callback_promise(stream.realm_, err.msg()) }
	}
	return resolved_callback_promise(stream.realm_)
}

fn (mut stream ReadableStream) invoke_cancel_algorithm(reason Value) &webidl.Promise {
	if algorithm := stream.promise_cancel_algorithm_ {
		return algorithm(reason) or { rejected_callback_promise(stream.realm_, err.msg()) }
	}
	if algorithm := stream.cancel_algorithm_ {
		algorithm(reason) or { return rejected_callback_promise(stream.realm_, err.msg()) }
	}
	return resolved_callback_promise(stream.realm_)
}

fn (mut stream ReadableStream) react_to_start(mut start_promise webidl.Promise) {
	webidl.react_to_promise(mut start_promise, fn [mut stream] (_ webidl.Value) !webidl.Value {
		stream.started_ = true
		assert !stream.pulling_
		assert !stream.pull_again_
		stream.call_pull_if_needed()
		return webidl.undefined_value()
	}, fn [mut stream] (reason webidl.Value) !webidl.Value {
		stream.error(callback_reason(reason))
		return webidl.undefined_value()
	})
}

fn (mut stream ReadableStream) start_underlying_source(source UnderlyingSource) ! {
	stream.promise_pull_algorithm_ = source.pull_promise
	stream.promise_cancel_algorithm_ = source.cancel_promise
	mut start_promise := if algorithm := source.start_promise {
		algorithm()!
	} else {
		if algorithm := source.start { algorithm()! }
		resolved_callback_promise(stream.realm_)
	}
	stream.react_to_start(mut start_promise)
}

fn (mut stream WritableStream) start_underlying_sink(sink UnderlyingSink) ! {
	stream.promise_write_algorithm_ = sink.write_promise
	stream.promise_close_algorithm_ = sink.close_promise
	stream.promise_abort_algorithm_ = sink.abort_promise
	mut start_promise := if algorithm := sink.start_promise {
		algorithm()!
	} else {
		if algorithm := sink.start { algorithm()! }
		resolved_callback_promise(stream.realm_)
	}
	webidl.react_to_promise(mut start_promise, fn [mut stream] (_ webidl.Value) !webidl.Value {
		assert stream.state_ in [.writable, .erroring]
		stream.started_ = true
		stream.process_queue()
		return webidl.undefined_value()
	}, fn [mut stream] (reason webidl.Value) !webidl.Value {
		assert stream.state_ in [.writable, .erroring]
		stream.started_ = true
		writable_stream_deal_with_rejection(mut stream, string_value(callback_reason(reason)))
		return webidl.undefined_value()
	})
}
