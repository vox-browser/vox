// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// ReadableStreamDefaultReader.cpp DefaultReaderReadRequest and
// ReadableStreamBYOBReader.cpp BYOBReaderReadIntoRequest resolve/reject the
// retained WebIDL capability; native read-result caches remain a typed facade.
module streams

import webidl

fn stream_read_result_value(value Value, done bool) webidl.Value {
	return webidl.object_value({
		'value': stream_value_to_webidl(value)
		'done': webidl.boolean_value(done)
	})
}

pub fn (promise &ReadPromise) as_webidl_promise() &webidl.Promise {
	mut owner := unsafe { &ReadPromise(promise) }
	return owner.ensure_native_promise()
}

fn (mut promise ReadPromise) ensure_native_promise() &webidl.Promise {
	if isnil(promise.native_promise_) {
		mut native := webidl.create_promise_for(promise.realm_.promise_context())
		promise.native_promise_ = native
		match promise.state_ {
			.pending {}
			.fulfilled { native.resolve(stream_read_result_value(promise.result_.value, promise.result_.done)) }
			.rejected { native.reject(webidl.string_value(promise.reason_)) }
		}
	}
	return promise.native_promise_
}

pub fn (promise &BYOBReadPromise) as_webidl_promise() &webidl.Promise {
	mut owner := unsafe { &BYOBReadPromise(promise) }
	return owner.ensure_native_promise()
}

fn (mut promise BYOBReadPromise) ensure_native_promise() &webidl.Promise {
	if isnil(promise.native_promise_) {
		mut native := webidl.create_promise_for(promise.realm_.promise_context())
		promise.native_promise_ = native
		match promise.state_ {
			.pending {}
			.fulfilled { native.resolve(stream_read_result_value(bytes_value(promise.result_.value), promise.result_.done)) }
			.rejected { native.reject(webidl.string_value(promise.reason_)) }
		}
	}
	return promise.native_promise_
}
