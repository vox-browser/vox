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
	readable_            &ReadableStream                   = unsafe { nil }
	writable_            &WritableStream                   = unsafe { nil }
	controller_          &TransformStreamDefaultController = unsafe { nil }
	transform_algorithm_ ?TransformAlgorithm
	flush_algorithm_     ?FlushAlgorithm
	cancel_algorithm_    ?CancelAlgorithm
	backpressure_        bool
	stored_error_        string
	terminated_          bool
}

pub fn TransformStream.construct_impl(transformer Transformer, writable_strategy QueuingStrategy, readable_strategy QueuingStrategy) !&TransformStream {
	if type_ := transformer.readable_type {
		return error('RangeError: Unsupported transformer readableType ${type_}')
	}
	if type_ := transformer.writable_type {
		return error('RangeError: Unsupported transformer writableType ${type_}')
	}
	mut transform := &TransformStream{
		transform_algorithm_: transformer.transform
		flush_algorithm_:     transformer.flush
		cancel_algorithm_:    transformer.cancel
	}
	readable_high_water_mark := extract_high_water_mark(readable_strategy, 0)!
	writable_high_water_mark := extract_high_water_mark(writable_strategy, 1)!
	transform.readable_ = ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{
		high_water_mark: readable_high_water_mark
		size:            readable_strategy.size
	})!
	transform.writable_ = WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{
		high_water_mark: writable_high_water_mark
		size:            writable_strategy.size
	})!
	transform.controller_ = &TransformStreamDefaultController{
		stream_: transform
	}
	transform.readable_.owner_kind_ = .transform
	transform.readable_.owner_ = voidptr(transform)
	transform.writable_.owner_kind_ = .transform
	transform.writable_.owner_ = voidptr(transform)
	if start := transformer.start {
		start() or {
			transform.error(err.msg())
			return transform
		}
	}
	transform.update_backpressure()
	return transform
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

fn (mut stream TransformStream) update_backpressure() {
	desired := stream.readable_.desired_size() or { 0.0 }
	stream.backpressure_ = desired <= 0
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
		outputs << value.clone()
	}
	mut controller := stream.controller_
	for output in outputs {
		controller.enqueue(output)!
	}
	stream.update_backpressure()
}

fn (mut stream TransformStream) close_writable() ! {
	if stream.stored_error_ != '' {
		return error(stream.stored_error_)
	}
	mut outputs := []Value{}
	if algorithm := stream.flush_algorithm_ {
		outputs = algorithm() or {
			stream.error(err.msg())
			return err
		}
	}
	mut controller := stream.controller_
	for output in outputs {
		controller.enqueue(output)!
	}
	mut readable_controller := stream.readable_.default_controller_
	readable_controller.close()!
}

fn (mut stream TransformStream) abort_writable(reason Value) {
	stream.error(reason.description())
}

fn (mut stream TransformStream) cancel_readable(reason Value) &VoidPromise {
	if algorithm := stream.cancel_algorithm_ {
		algorithm(reason) or {
			stream.error(err.msg())
			return VoidPromise.rejected(err.msg())
		}
	}
	mut writable := stream.writable_
	writable.start_erroring(reason.description())
	return VoidPromise.fulfilled()
}

pub fn (mut stream TransformStream) error(reason string) {
	if stream.stored_error_ != '' {
		return
	}
	stream.stored_error_ = reason
	mut readable := stream.readable_
	readable.error(reason)
	mut writable := stream.writable_
	writable.start_erroring(reason)
}

pub fn (mut stream TransformStream) terminate() {
	if stream.terminated_ {
		return
	}
	stream.terminated_ = true
	mut readable := stream.readable_
	readable.close()
	mut writable := stream.writable_
	writable.start_erroring('TypeError: TransformStream was terminated')
}

@[heap]
pub struct TransformStreamDefaultController {
mut:
	stream_ &TransformStream = unsafe { nil }
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
