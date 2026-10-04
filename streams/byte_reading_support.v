// Copyright (c) 2022, Linus Groh <linusg@serenityos.org>
// Copyright (c) 2023-2024, Shannon Booth <shannon@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// ReadableStream.cpp::set_up_with_byte_reading_support performs the full
// source controller setup, including relevant-realm start/pull/cancel Promises.
module streams

import webidl

pub fn ReadableStream.create_for_internal() &ReadableStream {
	// Source default constructor, before a realm/controller setup operation.
	return &ReadableStream{}
}

pub fn (mut stream ReadableStream) set_up_with_byte_reading_support_in_realm(realm StreamRealm, pull ?PromisePullAlgorithm, cancel ?PromiseCancelAlgorithm, high_water_mark f64) {
	stream.set_realm(realm)
	// The source wrappers forward actual supplied Promises; absent algorithms
	// produce the existing owning-realm resolved-undefined Promise adapters.
	initialize_readable_stream(mut stream)
	mut controller := &ReadableByteStreamController{ stream_: &stream }
	set_up_readable_byte_stream_controller_slots(mut stream, mut controller, no_op_pull_algorithm, no_op_cancel_algorithm, high_water_mark, none) or {
		panic('Source MUST: byte reading support setup failed: ${err.msg()}')
	}
	stream.start_underlying_source(UnderlyingSource{
		start:          no_op_start_algorithm
		pull_promise:   fn [realm, pull] () !&webidl.Promise {
			if algorithm := pull {
				return algorithm() or { rejected_callback_exception(realm, err) }
			}
			return resolved_callback_promise(realm)
		}
		cancel_promise: fn [realm, cancel] (reason Value) !&webidl.Promise {
			if algorithm := cancel {
				return algorithm(reason) or { rejected_callback_exception(realm, err) }
			}
			return resolved_callback_promise(realm)
		}
	}) or { panic('Source MUST: byte reading support start failed: ${err.msg()}') }
}
