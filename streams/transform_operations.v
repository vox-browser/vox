// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Direct TransformStream operations and slot accessors translated from
// TransformStream.cpp and TransformStreamOperations.cpp.
module streams

import webidl

pub fn (mut stream TransformStream) enqueue(value Value) ! {
	mut controller := stream.controller_
	controller.enqueue(value)!
}

pub fn (mut stream TransformStream) set_up(transformer Transformer, writable_strategy QueuingStrategy, readable_strategy QueuingStrategy) ! {
	if transformer.readable_type != none || transformer.writable_type != none {
		return error('RangeError: TransformStream type members are reserved')
	}
	mut start_promise := webidl.create_promise_for(stream.realm_.promise_context())
	initialize_transform_stream_with_start_promise(mut stream, start_promise, extract_high_water_mark(writable_strategy, 1)!, extract_size_algorithm(writable_strategy), extract_high_water_mark(readable_strategy, 0)!, extract_size_algorithm(readable_strategy))!
	set_up_transform_stream_default_controller_from_transformer(mut stream, transformer)
	stream.start_transformer(transformer, mut start_promise)!
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
	stream.backpressure_ = false
	stream.backpressure_change_promise_ = unsafe { nil }
	stream.controller_ = unsafe { nil }
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
	if stream.backpressure_ == value { return }
	mut changed := stream.backpressure_change_promise_
	stream.backpressure_change_promise_ = VoidPromise.pending_in(stream.realm_)
	stream.backpressure_ = value
	// Upstream resolves the old Promise before assigning these slots. Its jobs
	// run after the operation returns; installing the slots first preserves
	// that same visible state for the direct standalone reaction adapter.
	if !isnil(changed) { changed.resolve() }
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
	mut start_promise := webidl.create_promise_for(stream.realm_.promise_context())
	initialize_transform_stream_with_start_promise(mut stream, start_promise, writable_high_water_mark, writable_size, readable_high_water_mark, readable_size)!
	start_promise.resolve(webidl.undefined_value())
}

fn initialize_transform_stream_with_start_promise(mut stream TransformStream, start_promise &webidl.Promise, writable_high_water_mark f64, writable_size SizeAlgorithm, readable_high_water_mark f64, readable_size SizeAlgorithm) ! {
	stream.stored_error_ = ''
	stream.terminated_ = false
	stream.transform_algorithm_ = none
	stream.flush_algorithm_ = none
	stream.cancel_algorithm_ = none
	stream.writable_ = WritableStream.create(stream.realm_, UnderlyingSink{
		start_promise: fn [start_promise] () !&webidl.Promise { return start_promise }
	}, QueuingStrategy{
		high_water_mark: writable_high_water_mark
		size: writable_size
	})!
	stream.writable_.owner_kind_ = .transform
	stream.writable_.owner_ = voidptr(&stream)
	stream.readable_ = ReadableStream.create(stream.realm_, UnderlyingSource{
		start_promise: fn [start_promise] () !&webidl.Promise { return start_promise }
		cancel_promise: fn [mut stream] (reason Value) !&webidl.Promise { return stream.cancel_readable(reason).as_webidl_promise() }
	}, QueuingStrategy{
		high_water_mark: readable_high_water_mark
		size: readable_size
	})!
	stream.readable_.set_result_realm(stream.realm_)
	stream.readable_.owner_kind_ = .transform
	stream.readable_.owner_ = voidptr(&stream)
	stream.backpressure_ = false
	stream.backpressure_change_promise_ = unsafe { nil }
	stream.controller_ = unsafe { nil }
	transform_stream_set_backpressure(mut stream, true)
}

pub fn transform_stream_error(mut stream TransformStream, reason Value) {
	stream.error(reason.description())
}

pub fn transform_stream_error_writable_and_unblock_write(mut stream TransformStream, reason Value) {
	stream.stored_error_ = reason.description()
	stream.clear_algorithms()
	mut writable := stream.writable_
	writable.start_erroring(reason.description())
	stream.unblock_write()
}

pub fn transform_stream_set_backpressure(mut stream TransformStream, backpressure bool) {
	stream.set_backpressure(backpressure)
}

pub fn transform_stream_unblock_write(mut stream TransformStream) {
	stream.unblock_write()
}

pub fn set_up_transform_stream_default_controller(mut stream TransformStream, mut controller TransformStreamDefaultController, transform TransformAlgorithm, flush FlushAlgorithm, cancel CancelAlgorithm) {
	controller.stream_ = &stream
	controller.finish_promise_ = unsafe { nil }
	stream.controller_ = &controller
	stream.transform_algorithm_ = transform
	stream.flush_algorithm_ = flush
	stream.cancel_algorithm_ = cancel
	stream.promise_transform_algorithm_ = none
	stream.promise_flush_algorithm_ = none
	stream.promise_cancel_algorithm_ = none
}

pub fn set_up_transform_stream_default_controller_from_transformer(mut stream TransformStream, transformer Transformer) {
	mut controller := TransformStreamDefaultController{
		stream_: &stream
	}
	set_up_transform_stream_default_controller(mut stream, mut controller, transformer.transform or { identity_transform_algorithm }, transformer.flush or { empty_flush_algorithm }, transformer.cancel or { no_op_cancel_algorithm })
	stream.promise_transform_algorithm_ = transformer.transform_promise
	stream.promise_flush_algorithm_ = transformer.flush_promise
	stream.promise_cancel_algorithm_ = transformer.cancel_promise
}

fn identity_transform_algorithm(value Value) ![]Value {
	return [value]
}

fn empty_flush_algorithm() ![]Value {
	return []Value{}
}

pub fn transform_stream_default_controller_clear_algorithms(mut controller TransformStreamDefaultController) {
	mut stream := controller.stream_
	stream.clear_algorithms()
}

pub fn transform_stream_default_controller_enqueue(mut controller TransformStreamDefaultController, chunk Value) ! {
	controller.enqueue(chunk)!
}

pub fn transform_stream_default_controller_error(mut controller TransformStreamDefaultController, reason Value) {
	controller.error(reason.description())
}

pub fn transform_stream_default_controller_perform_transform(mut controller TransformStreamDefaultController, chunk Value) &VoidPromise {
	mut stream := controller.stream_
	mut native := stream.perform_transform_promise(chunk)
	return void_promise_from_webidl(stream.realm_, mut native)
}

pub fn transform_stream_default_controller_terminate(mut controller TransformStreamDefaultController) {
	controller.terminate()
}

pub fn transform_stream_default_sink_write_algorithm(mut stream TransformStream, chunk Value) &VoidPromise {
	mut native := stream.sink_write_promise(chunk)
	return void_promise_from_webidl(stream.realm_, mut native)
}

pub fn transform_stream_default_sink_abort_algorithm(mut stream TransformStream, reason Value) &VoidPromise {
	return stream.abort_writable(reason)
}

pub fn transform_stream_default_sink_close_algorithm(mut stream TransformStream) &VoidPromise {
	return stream.close_writable()
}

pub fn transform_stream_default_source_cancel_algorithm(mut stream TransformStream, reason Value) &VoidPromise {
	return stream.cancel_readable(reason)
}

pub fn transform_stream_default_source_pull_algorithm(mut stream TransformStream) &VoidPromise {
	assert stream.backpressure_
	stream.set_backpressure(false)
	return stream.backpressure_change_promise_
}
