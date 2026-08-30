// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Direct TransformStream operations and slot accessors.
module streams

pub fn Transformer.from_value(value Value) !Transformer {
	if value.kind in [.undefined, .null_] {
		return Transformer{}
	}
	return error('TypeError: Transformer callbacks must use the typed V boundary')
}

pub fn (mut stream TransformStream) enqueue(value Value) ! {
	mut controller := stream.controller_
	controller.enqueue(value)!
}

pub fn (mut stream TransformStream) set_up(transformer Transformer, writable_strategy QueuingStrategy, readable_strategy QueuingStrategy) ! {
	created := TransformStream.construct_impl(transformer, writable_strategy, readable_strategy)!
	stream = *created
}

pub fn (mut stream TransformStream) transfer_steps() !&TransformStream {
	mut transferred := TransformStream.construct_impl(Transformer{}, QueuingStrategy{}, QueuingStrategy{})!
	transferred.readable_ = stream.readable_.transfer()!
	transferred.writable_ = stream.writable_.transfer()!
	return transferred
}

pub fn (mut stream TransformStream) transfer_receiving_steps(mut source TransformStream) ! {
	received := source.transfer_steps()!
	stream.readable_ = received.readable_
	stream.writable_ = received.writable_
	stream.controller_ = received.controller_
	stream.controller_.stream_ = &stream
}

pub fn (mut stream TransformStream) set_readable(mut readable ReadableStream) {
	stream.readable_ = &readable
	readable.owner_kind_ = .transform
	readable.owner_ = voidptr(&stream)
}

pub fn (mut stream TransformStream) set_writable(mut writable WritableStream) {
	stream.writable_ = &writable
	writable.owner_kind_ = .transform
	writable.owner_ = voidptr(&stream)
}

pub fn (mut stream TransformStream) set_backpressure(value bool) {
	if stream.backpressure_ == value {
		return
	}
	if !isnil(stream.backpressure_change_promise_) {
		mut changed := stream.backpressure_change_promise_
		changed.resolve()
	}
	stream.backpressure_change_promise_ = VoidPromise.pending()
	stream.backpressure_ = value
}

pub fn (stream &TransformStream) backpressure_change_promise() &VoidPromise {
	return stream.backpressure_change_promise_
}

pub fn (mut stream TransformStream) set_backpressure_change_promise(promise &VoidPromise) {
	stream.backpressure_change_promise_ = promise
}

pub fn (mut stream TransformStream) set_controller(mut controller TransformStreamDefaultController) {
	stream.controller_ = &controller
	controller.stream_ = &stream
}

pub fn (_ &TransformStream) primary_interface() string {
	return 'TransformStream'
}

pub fn (controller &TransformStreamDefaultController) cancel_algorithm() ?CancelAlgorithm {
	return controller.stream_.cancel_algorithm_
}

pub fn (mut controller TransformStreamDefaultController) set_cancel_algorithm(value ?CancelAlgorithm) {
	controller.stream_.cancel_algorithm_ = value
}

pub fn (controller &TransformStreamDefaultController) finish_promise() ?&VoidPromise {
	if isnil(controller.finish_promise_) {
		return none
	}
	return controller.finish_promise_
}

pub fn (mut controller TransformStreamDefaultController) set_finish_promise(value ?&VoidPromise) {
	controller.finish_promise_ = value or { unsafe { nil } }
}

pub fn (controller &TransformStreamDefaultController) flush_algorithm() ?FlushAlgorithm {
	return controller.stream_.flush_algorithm_
}

pub fn (mut controller TransformStreamDefaultController) set_flush_algorithm(value ?FlushAlgorithm) {
	controller.stream_.flush_algorithm_ = value
}

pub fn (controller &TransformStreamDefaultController) transform_algorithm() ?TransformAlgorithm {
	return controller.stream_.transform_algorithm_
}

pub fn (mut controller TransformStreamDefaultController) set_transform_algorithm(value ?TransformAlgorithm) {
	controller.stream_.transform_algorithm_ = value
}

pub fn (controller &TransformStreamDefaultController) stream() &TransformStream {
	return controller.stream_
}

pub fn (mut controller TransformStreamDefaultController) set_stream(stream &TransformStream) {
	controller.stream_ = stream
}

pub fn initialize_transform_stream(mut stream TransformStream, writable_high_water_mark f64, writable_size SizeAlgorithm, readable_high_water_mark f64, readable_size SizeAlgorithm) ! {
	created := TransformStream.construct_impl(Transformer{}, QueuingStrategy{
		high_water_mark: writable_high_water_mark
		size: writable_size
	}, QueuingStrategy{
		high_water_mark: readable_high_water_mark
		size: readable_size
	})!
	stream = *created
}

pub fn transform_stream_error(mut stream TransformStream, reason Value) {
	stream.error(reason.description())
}

pub fn transform_stream_error_writable_and_unblock_write(mut stream TransformStream, reason Value) {
	stream.stored_error_ = reason.description()
	mut writable := stream.writable_
	writable.start_erroring(reason.description())
	transform_stream_unblock_write(mut stream)
}

pub fn transform_stream_set_backpressure(mut stream TransformStream, backpressure bool) {
	stream.set_backpressure(backpressure)
}

pub fn transform_stream_unblock_write(mut stream TransformStream) {
	if stream.backpressure_ {
		stream.set_backpressure(false)
	}
}

pub fn set_up_transform_stream_default_controller(mut stream TransformStream, mut controller TransformStreamDefaultController, transform TransformAlgorithm, flush FlushAlgorithm, cancel CancelAlgorithm) {
	controller.stream_ = &stream
	controller.finish_promise_ = unsafe { nil }
	stream.controller_ = &controller
	stream.transform_algorithm_ = transform
	stream.flush_algorithm_ = flush
	stream.cancel_algorithm_ = cancel
}

pub fn set_up_transform_stream_default_controller_from_transformer(mut stream TransformStream, transformer Transformer) {
	mut controller := TransformStreamDefaultController{
		stream_: &stream
	}
	set_up_transform_stream_default_controller(mut stream, mut controller, transformer.transform or { identity_transform_algorithm }, transformer.flush or { empty_flush_algorithm }, transformer.cancel or { no_op_cancel_algorithm })
}

fn identity_transform_algorithm(value Value) ![]Value {
	return [value.clone()]
}

fn empty_flush_algorithm() ![]Value {
	return []Value{}
}

pub fn transform_stream_default_controller_clear_algorithms(mut controller TransformStreamDefaultController) {
	controller.stream_.transform_algorithm_ = none
	controller.stream_.flush_algorithm_ = none
	controller.stream_.cancel_algorithm_ = none
}

pub fn transform_stream_default_controller_enqueue(mut controller TransformStreamDefaultController, chunk Value) ! {
	controller.enqueue(chunk)!
}

pub fn transform_stream_default_controller_error(mut controller TransformStreamDefaultController, reason Value) {
	controller.error(reason.description())
}

pub fn transform_stream_default_controller_perform_transform(mut controller TransformStreamDefaultController, chunk Value) &VoidPromise {
	mut stream := controller.stream_
	stream.write_chunk(chunk) or { return VoidPromise.rejected(err.msg()) }
	return VoidPromise.fulfilled()
}

pub fn transform_stream_default_controller_terminate(mut controller TransformStreamDefaultController) {
	controller.terminate()
}

pub fn transform_stream_default_sink_write_algorithm(mut stream TransformStream, chunk Value) &VoidPromise {
	stream.write_chunk(chunk) or { return VoidPromise.rejected(err.msg()) }
	return VoidPromise.fulfilled()
}

pub fn transform_stream_default_sink_abort_algorithm(mut stream TransformStream, reason Value) &VoidPromise {
	stream.abort_writable(reason)
	return VoidPromise.fulfilled()
}

pub fn transform_stream_default_sink_close_algorithm(mut stream TransformStream) &VoidPromise {
	stream.close_writable() or { return VoidPromise.rejected(err.msg()) }
	return VoidPromise.fulfilled()
}

pub fn transform_stream_default_source_cancel_algorithm(mut stream TransformStream, reason Value) &VoidPromise {
	return stream.cancel_readable(reason)
}

pub fn transform_stream_default_source_pull_algorithm(mut stream TransformStream) &VoidPromise {
	if stream.backpressure_ {
		stream.set_backpressure(false)
	}
	return VoidPromise.fulfilled()
}
