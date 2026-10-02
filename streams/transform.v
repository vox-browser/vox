// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of TransformStream, GenericTransformStream,
// TransformStreamDefaultController, Transformer, and transform operations.
module streams

import webidl

pub struct Transformer {
pub:
	start         ?StartAlgorithm
	transform     ?TransformAlgorithm
	flush         ?FlushAlgorithm
	cancel        ?CancelAlgorithm
	start_promise ?PromiseStartAlgorithm
	transform_promise ?PromiseTransformAlgorithm
	flush_promise ?PromiseFlushAlgorithm
	cancel_promise ?PromiseCancelAlgorithm
	readable_type ?string
	writable_type ?string
}

@[heap]
pub struct TransformStream {
mut:
	realm_                       StreamRealm
	readable_                    &ReadableStream = unsafe { nil }
	writable_                    &WritableStream = unsafe { nil }
	controller_                  &TransformStreamDefaultController = unsafe { nil }
	transform_algorithm_         ?TransformAlgorithm
	flush_algorithm_             ?FlushAlgorithm
	cancel_algorithm_            ?CancelAlgorithm
	promise_transform_algorithm_ ?PromiseTransformAlgorithm
	promise_flush_algorithm_     ?PromiseFlushAlgorithm
	promise_cancel_algorithm_    ?PromiseCancelAlgorithm
	backpressure_                bool
	backpressure_change_promise_ &VoidPromise = unsafe { nil }
	stored_error_                string
	terminated_                  bool
	wrappers_prepared_           bool
}

pub fn TransformStream.construct_impl(transformer Transformer, writable_strategy QueuingStrategy, readable_strategy QueuingStrategy) !&TransformStream {
	if type_ := transformer.readable_type {
		return error('RangeError: Unsupported transformer readableType ${type_}')
	}
	if type_ := transformer.writable_type {
		return error('RangeError: Unsupported transformer writableType ${type_}')
	}
	return TransformStream.create(StreamRealm{}, transformer, writable_strategy, readable_strategy)
}

pub fn TransformStream.create_for_constructor(realm StreamRealm, transformer Transformer, writable_strategy QueuingStrategy, readable_strategy QueuingStrategy) !&TransformStream {
	if transformer.readable_type != none {
		return error("RangeError: Invalid use of reserved key 'readableType'")
	}
	if transformer.writable_type != none {
		return error("RangeError: Invalid use of reserved key 'writableType'")
	}
	return TransformStream.create(realm, transformer, writable_strategy, readable_strategy)
}

pub fn TransformStream.create(realm StreamRealm, transformer Transformer, writable_strategy QueuingStrategy, readable_strategy QueuingStrategy) !&TransformStream {
	readable_high_water_mark := extract_high_water_mark(readable_strategy, 0)!
	writable_high_water_mark := extract_high_water_mark(writable_strategy, 1)!
	mut transform := &TransformStream{
		realm_: realm
	}
	mut start_promise := webidl.create_promise_for(realm.promise_context())
	initialize_transform_stream_with_start_promise(mut transform, start_promise, writable_high_water_mark, extract_size_algorithm(writable_strategy), readable_high_water_mark, extract_size_algorithm(readable_strategy))!
	prepare_transform_stream_readable_writable_wrappers(mut transform)
	set_up_transform_stream_default_controller_from_transformer(mut transform, transformer)
	transform.start_transformer(transformer, mut start_promise)!
	return transform
}

// The C++ offsets are consumed by generated wrappers. V exposes the same stable
// ordering as logical wrapper slots rather than raw byte offsets.
pub fn TransformStream.readable_offset() int {
	return 0
}

pub fn TransformStream.writable_offset() int {
	return 1
}

pub fn prepare_transform_stream_readable_writable_wrappers(mut stream TransformStream) {
	stream.wrappers_prepared_ = true
}

pub fn (stream &TransformStream) wrappers_are_prepared() bool {
	return stream.wrappers_prepared_
}

pub fn (stream &TransformStream) readable() &ReadableStream {
	return stream.readable_
}

pub fn (stream &TransformStream) writable() &WritableStream {
	return stream.writable_
}

pub fn (stream &TransformStream) controller() &TransformStreamDefaultController {
	return stream.controller_
}

pub fn (stream &TransformStream) backpressure() bool {
	return stream.backpressure_
}

pub fn (stream &TransformStream) backpressure_change_promise_realm() StreamRealm {
	return promise_realm(stream.backpressure_change_promise_)
}

fn (mut stream TransformStream) update_backpressure() {
	new_backpressure := readable_stream_default_controller_has_backpressure(stream.readable_.default_controller_)
	if stream.backpressure_ != new_backpressure {
		stream.set_backpressure(new_backpressure)
	}
}


fn (mut stream TransformStream) clear_algorithms() {
	stream.transform_algorithm_ = none
	stream.flush_algorithm_ = none
	stream.cancel_algorithm_ = none
	stream.promise_transform_algorithm_ = none
	stream.promise_flush_algorithm_ = none
	stream.promise_cancel_algorithm_ = none
}


fn (mut stream TransformStream) unblock_write() {
	if stream.backpressure_ {
		stream.set_backpressure(false)
	}
}

pub fn (mut stream TransformStream) error(reason string) {
	if stream.stored_error_ != '' {
		return
	}
	stream.stored_error_ = reason
	mut readable := stream.readable_
	readable.error(reason)
	stream.clear_algorithms()
	mut writable := stream.writable_
	writable.start_erroring(reason)
	stream.unblock_write()
}

pub fn (mut stream TransformStream) terminate() {
	if stream.terminated_ {
		return
	}
	stream.terminated_ = true
	mut readable := stream.readable_
	readable.close()
	stream.clear_algorithms()
	mut writable := stream.writable_
	writable.start_erroring('TypeError: Stream has been terminated.')
	stream.unblock_write()
}

@[heap]
pub struct TransformStreamDefaultController {
mut:
	stream_         &TransformStream = unsafe { nil }
	finish_promise_ &VoidPromise = unsafe { nil }
}

pub fn (controller &TransformStreamDefaultController) desired_size() ?f64 {
	return controller.stream_.readable_.desired_size()
}

pub fn (mut controller TransformStreamDefaultController) enqueue(value Value) ! {
	mut stream := controller.stream_
	if stream.terminated_ || stream.stored_error_ != '' {
		return error('TypeError: TransformStream controller cannot enqueue')
	}
	mut readable_controller := stream.readable_.default_controller_
	readable_controller.enqueue(value) or {
		stream.error(err.msg())
		return err
	}
	stream.update_backpressure()
}

pub fn (mut controller TransformStreamDefaultController) error(reason string) {
	mut stream := controller.stream_
	stream.error(reason)
}

pub fn (mut controller TransformStreamDefaultController) terminate() {
	mut stream := controller.stream_
	stream.terminate()
}

pub struct GenericTransformStream {
	transform_ &TransformStream
}

pub fn GenericTransformStream.from_transform(transform &TransformStream) GenericTransformStream {
	return GenericTransformStream{
		transform_: transform
	}
}

pub fn (stream &GenericTransformStream) readable() &ReadableStream {
	return stream.transform_.readable()
}

pub fn (stream &GenericTransformStream) writable() &WritableStream {
	return stream.transform_.writable()
}
