// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of TransformStream, GenericTransformStream,
// TransformStreamDefaultController, Transformer, and transform operations.
module streams

pub struct Transformer {
pub:
	start         ?StartAlgorithm
	transform     ?TransformAlgorithm
	flush         ?FlushAlgorithm
	cancel        ?CancelAlgorithm
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
	initialize_transform_stream(mut transform, writable_high_water_mark, extract_size_algorithm(writable_strategy), readable_high_water_mark, extract_size_algorithm(readable_strategy))!
	prepare_transform_stream_readable_writable_wrappers(mut transform)
	set_up_transform_stream_default_controller_from_transformer(mut transform, transformer)
	if start := transformer.start {
		start()!
	}
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
	return stream.backpressure_change_promise_.realm()
}

fn (mut stream TransformStream) update_backpressure() {
	desired := stream.readable_.desired_size() or { 0.0 }
	new_backpressure := desired <= 0
	if stream.backpressure_ != new_backpressure {
		if !isnil(stream.backpressure_change_promise_) {
			mut changed := stream.backpressure_change_promise_
			changed.resolve()
		}
		stream.backpressure_change_promise_ = VoidPromise.pending_in(stream.realm_)
		stream.backpressure_ = new_backpressure
	}
}

fn (mut stream TransformStream) write_chunk(value Value) ! {
	if stream.terminated_ {
		return error('TypeError: TransformStream has terminated')
	}
	if stream.stored_error_ != '' {
		return error(stream.stored_error_)
	}
	mut outputs := []Value{}
	if algorithm := stream.transform_algorithm_ {
		outputs = algorithm(value) or {
			stream.error(err.msg())
			return err
		}
	} else {
		outputs << value
	}
	mut controller := stream.controller_
	for output in outputs {
		controller.enqueue(output)!
	}
	stream.update_backpressure()
}

fn (mut stream TransformStream) clear_algorithms() {
	stream.transform_algorithm_ = none
	stream.flush_algorithm_ = none
	stream.cancel_algorithm_ = none
}

// https://streams.spec.whatwg.org/#transform-stream-default-sink-close-algorithm
fn (mut stream TransformStream) close_writable() &VoidPromise {
	mut controller := stream.controller_
	if !isnil(controller.finish_promise_) {
		return controller.finish_promise_
	}
	controller.finish_promise_ = VoidPromise.pending_in(stream.realm_)
	mut finish_promise := controller.finish_promise_
	mut outputs := []Value{}
	if algorithm := stream.flush_algorithm_ {
		outputs = algorithm() or {
			reason := err.msg()
			stream.clear_algorithms()
			mut readable := stream.readable_
			readable.error(reason)
			finish_promise.reject(reason)
			return finish_promise
		}
	}
	stream.clear_algorithms()
	if stream.readable_.state_ == .errored {
		finish_promise.reject(stream.readable_.stored_error_)
		return finish_promise
	}
	for output in outputs {
		controller.enqueue(output) or {
			reason := err.msg()
			mut readable := stream.readable_
			readable.error(reason)
			finish_promise.reject(reason)
			return finish_promise
		}
	}
	mut readable_controller := stream.readable_.default_controller_
	readable_controller.close() or {
		reason := err.msg()
		mut readable := stream.readable_
		readable.error(reason)
		finish_promise.reject(reason)
		return finish_promise
	}
	finish_promise.resolve()
	return finish_promise
}

// https://streams.spec.whatwg.org/#transform-stream-default-sink-abort-algorithm
fn (mut stream TransformStream) abort_writable(reason Value) &VoidPromise {
	mut controller := stream.controller_
	if !isnil(controller.finish_promise_) {
		return controller.finish_promise_
	}
	controller.finish_promise_ = VoidPromise.pending_in(stream.realm_)
	mut finish_promise := controller.finish_promise_
	if algorithm := stream.cancel_algorithm_ {
		algorithm(reason) or {
			rejection := err.msg()
			stream.clear_algorithms()
			mut readable := stream.readable_
			readable.error(rejection)
			finish_promise.reject(rejection)
			return finish_promise
		}
	}
	stream.clear_algorithms()
	if stream.readable_.state_ == .errored {
		finish_promise.reject(stream.readable_.stored_error_)
		return finish_promise
	}
	mut readable := stream.readable_
	readable.error(reason.description())
	finish_promise.resolve()
	return finish_promise
}

// https://streams.spec.whatwg.org/#transform-stream-default-source-cancel
fn (mut stream TransformStream) cancel_readable(reason Value) &VoidPromise {
	mut controller := stream.controller_
	if !isnil(controller.finish_promise_) {
		return controller.finish_promise_
	}
	controller.finish_promise_ = VoidPromise.pending_in(stream.realm_)
	mut finish_promise := controller.finish_promise_
	if algorithm := stream.cancel_algorithm_ {
		algorithm(reason) or {
			rejection := err.msg()
			stream.clear_algorithms()
			mut writable := stream.writable_
			writable.start_erroring(rejection)
			stream.unblock_write()
			finish_promise.reject(rejection)
			return finish_promise
		}
	}
	stream.clear_algorithms()
	if stream.writable_.state_ == .errored {
		finish_promise.reject(stream.writable_.stored_error_)
		return finish_promise
	}
	mut writable := stream.writable_
	writable.start_erroring(reason.description())
	stream.unblock_write()
	finish_promise.resolve()
	return finish_promise
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
