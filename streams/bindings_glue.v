// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Typed equivalents of the callback adapters in Streams/BindingsGlue. The
// JavaScript implementation wraps controllers and supplies a callback `this`
// value; the standalone V boundary passes those values explicitly.
module streams

import webidl

pub struct BindingsUnderlyingSource {
pub:
	type_                    ?UnderlyingSourceType
	start                    ?StartAlgorithm
	pull                     ?PullAlgorithm
	cancel                   ?CancelAlgorithm
	start_promise            ?PromiseStartAlgorithm
	pull_promise             ?PromisePullAlgorithm
	cancel_promise           ?PromiseCancelAlgorithm
	underlying_source_value  webidl.Value
	start_callback           ?webidl.CallbackType
	pull_callback            ?webidl.CallbackType
	cancel_callback          ?webidl.CallbackType
	auto_allocate_chunk_size ?u64
}

pub fn underlying_source_from_bindings(source BindingsUnderlyingSource) UnderlyingSource {
	source_type := source.type_ or { UnderlyingSourceType.default_source }
	return UnderlyingSource{
		type_:                    if source_type == .bytes {
			UnderlyingSourceType.bytes
		} else {
			UnderlyingSourceType.default_source
		}
		start:                    source.start
		pull:                     source.pull
		cancel:                   source.cancel
		start_promise:            source.start_promise
		pull_promise:             source.pull_promise
		cancel_promise:           source.cancel_promise
		underlying_source_value:  source.underlying_source_value
		start_callback:           source.start_callback
		pull_callback:            source.pull_callback
		cancel_callback:          source.cancel_callback
		auto_allocate_chunk_size: source.auto_allocate_chunk_size
	}
}

pub type ReadableByteStreamStartCallback = fn (receiver Value, controller &ReadableByteStreamController) !
pub type ReadableByteStreamPullCallback = fn (receiver Value, controller &ReadableByteStreamController) !
pub type ReadableStreamStartCallback = fn (receiver Value, controller &ReadableStreamDefaultController) !
pub type ReadableStreamPullCallback = fn (receiver Value, controller &ReadableStreamDefaultController) !
pub type WritableStreamStartCallback = fn (receiver Value, controller &WritableStreamDefaultController) !
pub type WritableStreamWriteCallback = fn (receiver Value, chunk Value, controller &WritableStreamDefaultController) !
pub type TransformStreamStartCallback = fn (receiver Value, controller &TransformStreamDefaultController) !
pub type TransformStreamTransformCallback = fn (receiver Value, chunk Value, controller &TransformStreamDefaultController) ![]Value
pub type TransformStreamFlushCallback = fn (receiver Value, controller &TransformStreamDefaultController) ![]Value

pub fn invoke_readable_byte_stream_start_algorithm_callback(callback ReadableByteStreamStartCallback, underlying_source Value, controller &ReadableByteStreamController) ! {
	callback(underlying_source, controller)!
}

pub fn invoke_readable_byte_stream_pull_algorithm_callback(realm StreamRealm, callback ReadableByteStreamPullCallback, underlying_source Value, controller &ReadableByteStreamController) &VoidPromise {
	callback(underlying_source, controller) or {
		return VoidPromise.rejected_in(realm, err.msg())
	}
	return VoidPromise.fulfilled_in(realm)
}

pub fn invoke_readable_stream_start_algorithm_callback(callback ReadableStreamStartCallback, underlying_source Value, controller &ReadableStreamDefaultController) ! {
	callback(underlying_source, controller)!
}

pub fn invoke_readable_stream_pull_algorithm_callback(realm StreamRealm, callback ReadableStreamPullCallback, underlying_source Value, controller &ReadableStreamDefaultController) &VoidPromise {
	callback(underlying_source, controller) or {
		return VoidPromise.rejected_in(realm, err.msg())
	}
	return VoidPromise.fulfilled_in(realm)
}

pub fn invoke_writable_stream_start_algorithm_callback(callback WritableStreamStartCallback, underlying_sink Value, controller &WritableStreamDefaultController) ! {
	callback(underlying_sink, controller)!
}

pub fn invoke_writable_stream_write_algorithm_callback(realm StreamRealm, callback WritableStreamWriteCallback, underlying_sink Value, chunk Value, controller &WritableStreamDefaultController) &VoidPromise {
	callback(underlying_sink, chunk, controller) or {
		return VoidPromise.rejected_in(realm, err.msg())
	}
	return VoidPromise.fulfilled_in(realm)
}

pub fn invoke_transform_stream_start_algorithm_callback(callback TransformStreamStartCallback, transformer Value, controller &TransformStreamDefaultController) ! {
	callback(transformer, controller)!
}

pub fn invoke_transform_stream_transform_algorithm_callback(callback TransformStreamTransformCallback, transformer Value, chunk Value, controller &TransformStreamDefaultController) ![]Value {
	return callback(transformer, chunk, controller)
}

pub fn invoke_transform_stream_flush_algorithm_callback(callback TransformStreamFlushCallback, transformer Value, controller &TransformStreamDefaultController) ![]Value {
	return callback(transformer, controller)
}
