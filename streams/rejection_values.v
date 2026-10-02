// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// ReadableStreamError and reader/consumer rejection retain JS::Value exactly.
// String caches remain for existing native callers; native capabilities receive
// the original WebIDL/runtime value without coercing an arbitrary JS object.
module streams

import webidl

pub fn VoidPromise.rejected_value_in(realm StreamRealm, reason webidl.Value) &VoidPromise {
	mut promise := VoidPromise.pending_in(realm)
	promise.reject_value(reason)
	return promise
}

pub fn ReadPromise.rejected_value_in(realm StreamRealm, result_realm ?StreamRealm, reason webidl.Value) &ReadPromise {
	mut promise := ReadPromise.pending_in(realm, result_realm)
	promise.reject_value(reason)
	return promise
}

pub fn BYOBReadPromise.rejected_value_in(realm StreamRealm, reason webidl.Value) &BYOBReadPromise {
	mut promise := BYOBReadPromise.pending_in(realm)
	promise.reject_value(reason)
	return promise
}

pub fn (stream &ReadableStream) stored_error_value() webidl.Value {
	return stream.stored_error_value_ or { webidl.string_value(stream.stored_error_) }
}

pub fn (mut stream ReadableStream) error_value(reason webidl.Value) {
	if stream.state_ != .readable { return }
	value := stream_value_from_webidl(reason)
	if stream.byte_stream_ && !isnil(stream.byte_controller_) {
		mut controller := stream.byte_controller_
		readable_byte_stream_controller_error(mut controller, value)
	} else if !isnil(stream.default_controller_) {
		mut controller := stream.default_controller_
		readable_stream_default_controller_error(mut controller, value)
	} else {
		stream.error_internal_value(reason, callback_reason(reason))
	}
}

// WritableStreamStartErroring preserves the stored JS::Value for all writer
// capabilities and queued/in-flight operations.
pub fn (stream &WritableStream) stored_error_value() webidl.Value {
	return stream.stored_error_value_ or { webidl.string_value(stream.stored_error_) }
}
