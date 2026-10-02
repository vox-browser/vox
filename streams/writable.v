// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WritableStream, WritableStreamDefaultController,
// WritableStreamDefaultWriter, UnderlyingSink, and writable abstract ops.
module streams

import webidl

pub enum WritableStreamState {
	writable
	erroring
	errored
	closed
}

pub struct UnderlyingSink {
pub:
	start ?StartAlgorithm
	write ?WriteAlgorithm
	close ?CloseAlgorithm
	abort ?AbortAlgorithm
	start_promise ?PromiseStartAlgorithm
	write_promise ?PromiseWriteAlgorithm
	close_promise ?PromiseCloseAlgorithm
	abort_promise ?PromiseAbortAlgorithm
	type_ ?string
}

enum WritableOwnerKind {
	regular
	transform
	message_port
}

@[heap]
pub struct WritableStream {
mut:
	realm_                   StreamRealm
	state_                   WritableStreamState
	stored_error_            string
	writer_                  &WritableStreamDefaultWriter = unsafe { nil }
	controller_              &WritableStreamDefaultController = unsafe { nil }
	queue_                   QueueWithSizes
	high_water_mark_         f64 = 1.0
	size_algorithm_          SizeAlgorithm = default_size_algorithm
	write_algorithm_         ?WriteAlgorithm
	close_algorithm_         ?CloseAlgorithm
	abort_algorithm_         ?AbortAlgorithm
	promise_write_algorithm_ ?PromiseWriteAlgorithm
	promise_close_algorithm_ ?PromiseCloseAlgorithm
	promise_abort_algorithm_ ?PromiseAbortAlgorithm
	started_                 bool
	backpressure_            bool
	owner_kind_              WritableOwnerKind
	owner_                   voidptr
	message_port_            &MessagePort = unsafe { nil }
	message_backpressure_    bool
	pipe_source_             &ReadableStream = unsafe { nil }
	written_values_          []Value
	close_request_           &VoidPromise = unsafe { nil }
	in_flight_write_request_ &VoidPromise = unsafe { nil }
	in_flight_close_request_ &VoidPromise = unsafe { nil }
	pending_abort_request_   &VoidPromise = unsafe { nil }
	pending_abort_reason_    Value
	pending_abort_erroring_  bool
	write_requests_          VoidPromiseList
}

pub fn WritableStream.construct_impl(sink UnderlyingSink, strategy QueuingStrategy) !&WritableStream {
	if type_ := sink.type_ {
		return error('RangeError: Unsupported underlying sink type ${type_}')
	}
	return WritableStream.create(StreamRealm{}, sink, strategy)
}

pub fn WritableStream.create_for_constructor(realm StreamRealm, sink UnderlyingSink, strategy QueuingStrategy) !&WritableStream {
	if type_ := sink.type_ {
		return error("RangeError: Invalid use of reserved key 'type' (${type_})")
	}
	return WritableStream.create(realm, sink, strategy)
}

pub fn WritableStream.create(realm StreamRealm, sink UnderlyingSink, strategy QueuingStrategy) !&WritableStream {
	size_algorithm := extract_size_algorithm(strategy)
	high_water_mark := extract_high_water_mark(strategy, 1.0)!
	mut stream := &WritableStream{
		realm_: realm
	}
	initialize_writable_stream(mut stream)
	set_up_writable_stream_default_controller_from_underlying_sink(mut stream, sink, high_water_mark, size_algorithm)!
	return stream
}

pub fn (stream &WritableStream) realm() StreamRealm {
	return stream.realm_
}

pub fn (stream &WritableStream) state() WritableStreamState {
	return stream.state_
}

pub fn (stream &WritableStream) stored_error() string {
	return stream.stored_error_
}

pub fn (stream &WritableStream) locked() bool {
	return !isnil(stream.writer_)
}

pub fn (stream &WritableStream) backpressure() bool {
	return stream.backpressure_
}

pub fn (stream &WritableStream) queue_total_size() f64 {
	return stream.queue_.total_size()
}

pub fn (stream &WritableStream) written_values() []Value {
	mut values := []Value{cap: stream.written_values_.len}
	for value in stream.written_values_ {
		values << value.clone()
	}
	return values
}

pub fn (stream &WritableStream) controller() &WritableStreamDefaultController {
	return stream.controller_
}

fn (stream &WritableStream) desired_size_internal() ?f64 {
	return match stream.state_ {
		.errored, .erroring { none }
		.closed { 0.0 }
		.writable { stream.high_water_mark_ - stream.queue_.total_size() }
	}
}

fn (mut stream WritableStream) update_backpressure() {
	new_backpressure := if desired := stream.desired_size_internal() {
		desired <= 0
	} else {
		false
	}
	writable_stream_update_backpressure(mut stream, new_backpressure)
}

fn (mut stream WritableStream) start_erroring(reason string) {
	if stream.state_ != .writable {
		return
	}
	stream.state_ = .erroring
	stream.stored_error_ = reason
	if !isnil(stream.writer_) {
		mut writer := stream.writer_
			if writer.ready_.state() == .pending {
			mut ready := writer.ready_
			ready.reject(reason)
			} else {
				writer.ready_ = VoidPromise.rejected_in(writer.ready_promise_realm(), reason)
		}
	}
	if !writable_stream_has_operation_marked_in_flight(stream) && stream.started_ {
		stream.finish_erroring()
	}
	if !isnil(stream.pipe_source_) {
		mut source := stream.pipe_source_
		pump_readable_pipe(mut source)
	}
}

fn (mut stream WritableStream) finish_erroring() {
	if stream.state_ != .erroring || writable_stream_has_operation_marked_in_flight(stream) {
		return
	}
	stream.state_ = .errored
	stream.queue_.reset()
	for mut request in stream.write_requests_.values() {
		request.reject(stream.stored_error_)
	}
	stream.write_requests_.clear()
	if isnil(stream.pending_abort_request_) {
		writable_stream_reject_close_and_closed_promise_if_needed(mut stream)
		return
	}
	mut abort_request := stream.pending_abort_request_
	was_already_erroring := stream.pending_abort_erroring_
	reason := stream.pending_abort_reason_
	stream.pending_abort_request_ = unsafe { nil }
	stream.pending_abort_reason_ = undefined_value()
	stream.pending_abort_erroring_ = false
	if was_already_erroring {
		abort_request.reject(stream.stored_error_)
		writable_stream_reject_close_and_closed_promise_if_needed(mut stream)
		return
	}
	mut controller := stream.controller_
	mut abort_result := controller.abort_steps_promise(reason)
	webidl.react_to_promise(mut abort_result, fn [mut stream, mut abort_request] (_ webidl.Value) !webidl.Value {
		abort_request.resolve()
		writable_stream_reject_close_and_closed_promise_if_needed(mut stream)
		return webidl.undefined_value()
	}, fn [mut stream, mut abort_request] (error webidl.Value) !webidl.Value {
		abort_request.reject(callback_reason(error))
		writable_stream_reject_close_and_closed_promise_if_needed(mut stream)
		return webidl.undefined_value()
	})
}

fn (mut stream WritableStream) perform_write(value Value) &webidl.Promise {
	match stream.owner_kind_ {
		.regular {
			if algorithm := stream.promise_write_algorithm_ {
				return algorithm(value) or { rejected_callback_promise(stream.realm_, err.msg()) }
			}
			if algorithm := stream.write_algorithm_ {
				algorithm(value) or { return rejected_callback_promise(stream.realm_, err.msg()) }
			}
		}
		.transform {
			mut transform := unsafe { &TransformStream(stream.owner_) }
			return transform.sink_write_promise(value)
		}
		.message_port {
			if isnil(stream.message_port_) {
				return rejected_callback_promise(stream.realm_, 'DataCloneError: Cross-realm writable endpoint is unavailable')
			}
			mut port := stream.message_port_
			pack_and_post_message(mut port, 'chunk', value) or { return rejected_callback_promise(stream.realm_, err.msg()) }
			stream.message_backpressure_ = false
		}
	}
	return resolved_callback_promise(stream.realm_)
}

fn (mut stream WritableStream) perform_close() &webidl.Promise {
	match stream.owner_kind_ {
		.regular {
			if algorithm := stream.promise_close_algorithm_ {
				return algorithm() or { rejected_callback_promise(stream.realm_, err.msg()) }
			}
			if algorithm := stream.close_algorithm_ {
				algorithm() or { return rejected_callback_promise(stream.realm_, err.msg()) }
			}
		}
		.transform {
			mut transform := unsafe { &TransformStream(stream.owner_) }
			return transform.close_writable().as_webidl_promise()
		}
		.message_port {
			if !isnil(stream.message_port_) {
				mut port := stream.message_port_
				pack_and_post_message(mut port, 'close', undefined_value()) or {
					return rejected_callback_promise(stream.realm_, err.msg())
				}
			}
		}
	}
	return resolved_callback_promise(stream.realm_)
}

fn (mut stream WritableStream) perform_abort(reason Value) &webidl.Promise {
	match stream.owner_kind_ {
		.regular {
			if algorithm := stream.promise_abort_algorithm_ {
				return algorithm(reason) or { rejected_callback_promise(stream.realm_, err.msg()) }
			}
			if algorithm := stream.abort_algorithm_ {
				algorithm(reason) or { return rejected_callback_promise(stream.realm_, err.msg()) }
			}
		}
		.transform {
			mut transform := unsafe { &TransformStream(stream.owner_) }
			return transform.abort_writable(reason).as_webidl_promise()
		}
		.message_port {
			if !isnil(stream.message_port_) {
				mut port := stream.message_port_
				pack_and_post_message(mut port, 'error', reason) or {
					return rejected_callback_promise(stream.realm_, err.msg())
				}
			}
		}
	}
	return resolved_callback_promise(stream.realm_)
}

fn (mut stream WritableStream) process_queue() {
	if !stream.started_ || writable_stream_has_operation_marked_in_flight(stream)
		|| stream.state_ in [
			.closed,
			.errored,
		] {
		return
	}
	if stream.state_ == .erroring {
		stream.finish_erroring()
		return
	}
	value := stream.queue_.peek_queue_value() or { return }
	is_close := stream.queue_.first_is_close_sentinel()

	if stream.owner_kind_ == .message_port && !is_close && !stream.message_backpressure_ {
		return
	}
	mut controller := stream.controller_
	if is_close {
		writable_stream_default_controller_process_close(mut controller)
	} else {
		writable_stream_default_controller_process_write(mut controller, value)
	}
}

fn (mut stream WritableStream) write_internal(value Value) &VoidPromise {
	return stream.write_internal_in(value, stream.realm_)
}

fn (mut stream WritableStream) write_internal_in(value Value, promise_realm StreamRealm) &VoidPromise {
	mut controller := stream.controller_
	chunk_size := writable_stream_default_controller_get_chunk_size(mut controller, value) or {
		return VoidPromise.rejected_in(promise_realm, err.msg())
	}
	if stream.state_ == .errored || stream.state_ == .erroring {
		return VoidPromise.rejected_in(promise_realm, stream.stored_error_)
	}
	if stream.state_ == .closed || writable_stream_close_queued_or_in_flight(stream) {
		return VoidPromise.rejected_in(promise_realm, 'TypeError: WritableStream is closing or closed')
	}
	mut request := VoidPromise.pending_in(promise_realm)
	stream.write_requests_.append(request)
	writable_stream_default_controller_write(mut controller, value, chunk_size) or {
		if request.state() == .pending {
			request.reject(err.msg())
		}
	}
	return request
}

fn (mut stream WritableStream) close_internal() &VoidPromise {
	return stream.close_internal_in(stream.realm_)
}

fn (mut stream WritableStream) close_internal_in(promise_realm StreamRealm) &VoidPromise {
	if stream.state_ == .closed {
		return VoidPromise.rejected_in(promise_realm, 'TypeError: WritableStream is already closed')
	}
	if stream.state_ == .errored || stream.state_ == .erroring {
		return VoidPromise.rejected_in(promise_realm, stream.stored_error_)
	}
	if writable_stream_close_queued_or_in_flight(stream) {
		return VoidPromise.rejected_in(promise_realm, 'TypeError: WritableStream is already closing')
	}
	request := VoidPromise.pending_in(promise_realm)
	stream.close_request_ = request
	if !isnil(stream.writer_) && stream.backpressure_ && stream.state_ == .writable {
		mut ready := stream.writer_.ready_
		ready.resolve()
	}
	mut controller := stream.controller_
	writable_stream_default_controller_close(mut controller)
	return request
}

fn (mut stream WritableStream) abort_internal(reason Value) &VoidPromise {
	return stream.abort_internal_in(reason, stream.realm_)
}

fn (mut stream WritableStream) abort_internal_in(reason Value, promise_realm StreamRealm) &VoidPromise {
	if stream.state_ in [.closed, .errored] {
		return VoidPromise.fulfilled_in(promise_realm)
	}
	mut signal := stream.controller_.signal_
	signal.abort(reason)
	if !isnil(stream.pending_abort_request_) {
		return stream.pending_abort_request_
	}
	was_already_erroring := stream.state_ == .erroring
	request := VoidPromise.pending_in(promise_realm)
	stream.pending_abort_request_ = request
	stream.pending_abort_reason_ = if was_already_erroring {
		undefined_value()
	} else {
		reason
	}
	stream.pending_abort_erroring_ = was_already_erroring
	if !was_already_erroring {
		stream.start_erroring(reason.description())
	} else if !writable_stream_has_operation_marked_in_flight(stream) && stream.started_ {
		stream.finish_erroring()
	}
	return request
}

pub fn (mut stream WritableStream) close() &VoidPromise {
	if stream.locked() {
		return VoidPromise.rejected_in(stream.realm_, 'TypeError: Cannot close a locked WritableStream')
	}
	return stream.close_internal()
}

pub fn (mut stream WritableStream) abort(reason Value) &VoidPromise {
	if stream.locked() {
		return VoidPromise.rejected_in(stream.realm_, 'TypeError: Cannot abort a locked WritableStream')
	}
	return stream.abort_internal(reason)
}

pub fn (mut stream WritableStream) get_writer() !&WritableStreamDefaultWriter {
	return WritableStreamDefaultWriter.create(stream.realm_, mut stream)
}

pub fn WritableStreamDefaultWriter.create(realm StreamRealm, mut stream WritableStream) !&WritableStreamDefaultWriter {
	if stream.locked() {
		return error('TypeError: WritableStream is already locked')
	}
	mut closed := VoidPromise.pending_in(realm)
	mut ready := VoidPromise.fulfilled_in(realm)
	if stream.state_ == .closed {
		closed.resolve()
	} else if stream.state_ == .erroring {
		ready = VoidPromise.rejected_in(realm, stream.stored_error_)
	} else if stream.state_ == .errored {
		closed.reject(stream.stored_error_)
		ready = VoidPromise.rejected_in(realm, stream.stored_error_)
	} else if stream.backpressure_ {
		ready = VoidPromise.pending_in(realm)
	}
	writer := &WritableStreamDefaultWriter{
		stream_: &stream
		closed_: closed
		ready_: ready
	}
	stream.writer_ = writer
	return writer
}

@[heap]
pub struct WritableStreamDefaultController {
mut:
	stream_ &WritableStream = unsafe { nil }
	signal_ &AbortSignal = unsafe { nil }
}

pub fn (controller &WritableStreamDefaultController) signal() &AbortSignal {
	return controller.signal_
}

// Generated bindings address this first exposed controller slot by offset. V
// exposes the corresponding logical slot index instead of a C++ byte offset.
pub fn WritableStreamDefaultController.signal_offset() int {
	return 0
}

pub fn (mut controller WritableStreamDefaultController) error(reason string) {
	writable_stream_default_controller_error_if_needed(mut controller, string_value(reason))
}

@[heap]
pub struct WritableStreamDefaultWriter {
mut:
	stream_   &WritableStream = unsafe { nil }
	closed_   &VoidPromise = unsafe { nil }
	ready_    &VoidPromise = unsafe { nil }
	released_ bool
}

pub fn WritableStreamDefaultWriter.construct_impl(mut stream WritableStream) !&WritableStreamDefaultWriter {
	return WritableStreamDefaultWriter.create(stream.realm_, mut stream)
}

pub fn (writer &WritableStreamDefaultWriter) closed() &VoidPromise {
	return writer.closed_
}

pub fn (writer &WritableStreamDefaultWriter) desired_size() ?f64 {
	if writer.released_ || isnil(writer.stream_) {
		return none
	}
	return writer.stream_.desired_size_internal()
}

pub fn (writer &WritableStreamDefaultWriter) ready() &VoidPromise {
	return writer.ready_
}

pub fn (writer &WritableStreamDefaultWriter) closed_promise_realm() StreamRealm {
	return writer.closed_.realm()
}

pub fn (writer &WritableStreamDefaultWriter) ready_promise_realm() StreamRealm {
	return writer.ready_.realm()
}

pub fn (mut writer WritableStreamDefaultWriter) write(value Value) &VoidPromise {
	if writer.released_ || isnil(writer.stream_) {
		return VoidPromise.rejected_in(writer.ready_promise_realm(), 'TypeError: Writer has no associated stream')
	}
	mut stream := writer.stream_
	return stream.write_internal_in(value, writer.ready_promise_realm())
}

pub fn (mut writer WritableStreamDefaultWriter) close() &VoidPromise {
	if writer.released_ || isnil(writer.stream_) {
		return VoidPromise.rejected_in(writer.closed_promise_realm(), 'TypeError: Writer has no associated stream')
	}
	mut stream := writer.stream_
	return stream.close_internal_in(writer.closed_promise_realm())
}

pub fn (mut writer WritableStreamDefaultWriter) abort(reason Value) &VoidPromise {
	if writer.released_ || isnil(writer.stream_) {
		return VoidPromise.rejected_in(writer.closed_promise_realm(), 'TypeError: Writer has no associated stream')
	}
	mut stream := writer.stream_
	return stream.abort_internal_in(reason, writer.closed_promise_realm())
}

pub fn (mut writer WritableStreamDefaultWriter) release_lock() {
	if writer.released_ || isnil(writer.stream_) {
		return
	}
	mut stream := writer.stream_
	stream.writer_ = unsafe { nil }
	writer.released_ = true
	writer.stream_ = unsafe { nil }
	if writer.ready_.state() == .pending {
		mut ready := writer.ready_
		ready.reject('TypeError: Writer was released')
	} else {
		writer.ready_ = VoidPromise.rejected_in(writer.ready_promise_realm(), 'TypeError: Writer was released')
	}
	if writer.closed_.state() == .pending {
		mut closed := writer.closed_
		closed.reject('TypeError: Writer was released')
	} else {
		writer.closed_ = VoidPromise.rejected_in(writer.closed_promise_realm(), 'TypeError: Writer was released')
	}
}
