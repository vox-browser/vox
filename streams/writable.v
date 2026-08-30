// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WritableStream, WritableStreamDefaultController,
// WritableStreamDefaultWriter, UnderlyingSink, and writable abstract ops.
module streams

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
	type_ ?string
}

enum WritableOwnerKind {
	regular
	transform
	transfer_proxy
	message_port
}

@[heap]
pub struct WritableStream {
mut:
	state_                WritableStreamState
	stored_error_         string
	writer_               &WritableStreamDefaultWriter     = unsafe { nil }
	controller_           &WritableStreamDefaultController = unsafe { nil }
	queue_                QueueWithSizes
	high_water_mark_      f64           = 1.0
	size_algorithm_       SizeAlgorithm = default_size_algorithm
	write_algorithm_      ?WriteAlgorithm
	close_algorithm_      ?CloseAlgorithm
	abort_algorithm_      ?AbortAlgorithm
	backpressure_         bool
	close_queued_         bool
	in_flight_write_      bool
	in_flight_close_      bool
	owner_kind_           WritableOwnerKind
	owner_                voidptr
	transfer_destination_ &WritableStream = unsafe { nil }
	message_port_         &MessagePort = unsafe { nil }
	transfer_locked_      bool
	pipe_source_          &ReadableStream = unsafe { nil }
	written_values_       []Value
	close_request_        &VoidPromise = unsafe { nil }
	in_flight_write_request_ &VoidPromise = unsafe { nil }
	in_flight_close_request_ &VoidPromise = unsafe { nil }
	pending_abort_request_ &VoidPromise = unsafe { nil }
	write_requests_       []&VoidPromise
}

pub fn WritableStream.construct_impl(sink UnderlyingSink, strategy QueuingStrategy) !&WritableStream {
	if type_ := sink.type_ {
		return error('RangeError: Unsupported underlying sink type ${type_}')
	}
	high_water_mark := extract_high_water_mark(strategy, 1.0)!
	mut stream := &WritableStream{
		high_water_mark_: high_water_mark
		size_algorithm_:  extract_size_algorithm(strategy)
		write_algorithm_: sink.write
		close_algorithm_: sink.close
		abort_algorithm_: sink.abort
	}
	stream.controller_ = &WritableStreamDefaultController{
		stream_: stream
		signal_: AbortSignal.create()
	}
	if start := sink.start {
		start() or { stream.start_erroring(err.msg()) }
	}
	stream.update_backpressure()
	return stream
}

pub fn (stream &WritableStream) state() WritableStreamState {
	return stream.state_
}

pub fn (stream &WritableStream) stored_error() string {
	return stream.stored_error_
}

pub fn (stream &WritableStream) locked() bool {
	return !isnil(stream.writer_) || stream.transfer_locked_
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
	if stream.backpressure_ == new_backpressure {
		return
	}
	stream.backpressure_ = new_backpressure
	if !isnil(stream.writer_) {
		mut writer := stream.writer_
		if new_backpressure {
			writer.ready_ = VoidPromise.pending()
		} else {
			mut ready := writer.ready_
			ready.resolve()
		}
	}
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
			writer.ready_ = VoidPromise.rejected(reason)
		}
	}
	mut signal := stream.controller_.signal_
	signal.abort(string_value(reason))
	stream.finish_erroring()
	if !isnil(stream.pipe_source_) {
		mut source := stream.pipe_source_
		pump_readable_pipe(mut source)
	}
}

fn (mut stream WritableStream) finish_erroring() {
	stream.state_ = .errored
	stream.queue_.reset()
	stream.close_queued_ = false
	if !isnil(stream.writer_) {
		mut closed := stream.writer_.closed_
		closed.reject(stream.stored_error_)
	}
}

fn (mut stream WritableStream) perform_write(value Value) ! {
	match stream.owner_kind_ {
		.regular {
			if algorithm := stream.write_algorithm_ {
				algorithm(value)!
			}
		}
		.transform {
			mut transform := unsafe { &TransformStream(stream.owner_) }
			transform.write_chunk(value)!
		}
		.transfer_proxy {
			if isnil(stream.transfer_destination_) {
				return error('DataCloneError: Transferred writable endpoint is unavailable')
			}
			mut destination := stream.transfer_destination_
			result := destination.write_internal(structured_clone(value))
			if result.state() == .rejected {
				return error(result.reason())
			}
		}
		.message_port {
			if isnil(stream.message_port_) {
				return error('DataCloneError: Cross-realm writable endpoint is unavailable')
			}
			mut port := stream.message_port_
			pack_and_post_message(mut port, 'chunk', value)!
		}
	}
}

fn (mut stream WritableStream) process_queue() {
	if stream.state_ != .writable || stream.in_flight_write_ {
		return
	}
	for !stream.queue_.is_empty() && stream.state_ == .writable {
		stream.in_flight_write_ = true
		value := stream.queue_.dequeue_value() or {
			stream.in_flight_write_ = false
			stream.start_erroring(err.msg())
			return
		}
		stream.perform_write(value) or {
			stream.in_flight_write_ = false
			stream.start_erroring(err.msg())
			return
		}
		stream.written_values_ << value.clone()
		stream.in_flight_write_ = false
		stream.update_backpressure()
	}
	if stream.close_queued_ && stream.queue_.is_empty() && stream.state_ == .writable {
		stream.finish_close()
	}
}

fn (mut stream WritableStream) write_internal(value Value) &VoidPromise {
	if stream.state_ == .errored || stream.state_ == .erroring {
		return VoidPromise.rejected(stream.stored_error_)
	}
	if stream.state_ == .closed || stream.close_queued_ {
		return VoidPromise.rejected('TypeError: WritableStream is closing or closed')
	}
	size := stream.size_algorithm_(value) or {
		stream.start_erroring(err.msg())
		return VoidPromise.rejected(err.msg())
	}
	stream.queue_.enqueue_value_with_size(value, size) or {
		stream.start_erroring(err.msg())
		return VoidPromise.rejected(err.msg())
	}
	stream.update_backpressure()
	stream.process_queue()
	if stream.state_ == .errored {
		return VoidPromise.rejected(stream.stored_error_)
	}
	return VoidPromise.fulfilled()
}

fn (mut stream WritableStream) finish_close() {
	stream.in_flight_close_ = true
	match stream.owner_kind_ {
		.regular {
			if algorithm := stream.close_algorithm_ {
				algorithm() or {
					stream.in_flight_close_ = false
					stream.start_erroring(err.msg())
					return
				}
			}
		}
		.transform {
			mut transform := unsafe { &TransformStream(stream.owner_) }
			transform.close_writable() or {
				stream.in_flight_close_ = false
				stream.start_erroring(err.msg())
				return
			}
		}
		.transfer_proxy {
			if !isnil(stream.transfer_destination_) {
				mut destination := stream.transfer_destination_
				result := destination.close_internal()
				if result.state() == .rejected {
					stream.in_flight_close_ = false
					stream.start_erroring(result.reason())
					return
				}
			}
		}
		.message_port {
			if !isnil(stream.message_port_) {
				mut port := stream.message_port_
				pack_and_post_message(mut port, 'close', undefined_value()) or {
					stream.in_flight_close_ = false
					stream.start_erroring(err.msg())
					return
				}
			}
		}
	}
	stream.in_flight_close_ = false
	stream.state_ = .closed
	if !isnil(stream.writer_) {
		mut ready := stream.writer_.ready_
		ready.resolve()
		mut closed := stream.writer_.closed_
		closed.resolve()
	}
}

fn (mut stream WritableStream) close_internal() &VoidPromise {
	if stream.state_ == .closed {
		return VoidPromise.rejected('TypeError: WritableStream is already closed')
	}
	if stream.state_ == .errored || stream.state_ == .erroring {
		return VoidPromise.rejected(stream.stored_error_)
	}
	if stream.close_queued_ {
		return VoidPromise.rejected('TypeError: WritableStream is already closing')
	}
	stream.close_queued_ = true
	stream.process_queue()
	if stream.state_ == .errored {
		return VoidPromise.rejected(stream.stored_error_)
	}
	return VoidPromise.fulfilled()
}

fn (mut stream WritableStream) abort_internal(reason Value) &VoidPromise {
	if stream.state_ == .closed {
		return VoidPromise.fulfilled()
	}
	if stream.state_ == .errored {
		return VoidPromise.rejected(stream.stored_error_)
	}
	mut signal := stream.controller_.signal_
	signal.abort(reason)
	match stream.owner_kind_ {
		.regular {
			if algorithm := stream.abort_algorithm_ {
				algorithm(reason) or {
					stream.start_erroring(err.msg())
					return VoidPromise.rejected(err.msg())
				}
			}
		}
		.transform {
			mut transform := unsafe { &TransformStream(stream.owner_) }
			transform.abort_writable(reason)
		}
		.transfer_proxy {
			if !isnil(stream.transfer_destination_) {
				mut destination := stream.transfer_destination_
				return destination.abort_internal(structured_clone(reason))
			}
		}
		.message_port {
			if !isnil(stream.message_port_) {
				mut port := stream.message_port_
				pack_and_post_message_handling_error(mut port, 'error', reason)
			}
		}
	}
	stream.start_erroring(reason.description())
	return VoidPromise.fulfilled()
}

pub fn (mut stream WritableStream) close() &VoidPromise {
	if stream.locked() {
		return VoidPromise.rejected('TypeError: Cannot close a locked WritableStream')
	}
	return stream.close_internal()
}

pub fn (mut stream WritableStream) abort(reason Value) &VoidPromise {
	if stream.locked() {
		return VoidPromise.rejected('TypeError: Cannot abort a locked WritableStream')
	}
	return stream.abort_internal(reason)
}

pub fn (mut stream WritableStream) get_writer() !&WritableStreamDefaultWriter {
	if stream.locked() {
		return error('TypeError: WritableStream is already locked')
	}
	mut closed := VoidPromise.pending()
	mut ready := VoidPromise.fulfilled()
	if stream.state_ == .closed {
		closed.resolve()
	} else if stream.state_ == .errored {
		closed.reject(stream.stored_error_)
		ready = VoidPromise.rejected(stream.stored_error_)
	} else if stream.backpressure_ {
		ready = VoidPromise.pending()
	}
	writer := &WritableStreamDefaultWriter{
		stream_: &stream
		closed_: closed
		ready_:  ready
	}
	stream.writer_ = writer
	return writer
}

@[heap]
pub struct WritableStreamDefaultController {
mut:
	stream_ &WritableStream = unsafe { nil }
	signal_ &AbortSignal    = unsafe { nil }
}

pub fn (controller &WritableStreamDefaultController) signal() &AbortSignal {
	return controller.signal_
}

pub fn (mut controller WritableStreamDefaultController) error(reason string) {
	mut stream := controller.stream_
	stream.start_erroring(reason)
}

@[heap]
pub struct WritableStreamDefaultWriter {
mut:
	stream_   &WritableStream = unsafe { nil }
	closed_   &VoidPromise    = unsafe { nil }
	ready_    &VoidPromise    = unsafe { nil }
	released_ bool
}

pub fn WritableStreamDefaultWriter.construct_impl(mut stream WritableStream) !&WritableStreamDefaultWriter {
	return stream.get_writer()
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

pub fn (mut writer WritableStreamDefaultWriter) write(value Value) &VoidPromise {
	if writer.released_ || isnil(writer.stream_) {
		return VoidPromise.rejected('TypeError: Writer has no associated stream')
	}
	mut stream := writer.stream_
	return stream.write_internal(value)
}

pub fn (mut writer WritableStreamDefaultWriter) close() &VoidPromise {
	if writer.released_ || isnil(writer.stream_) {
		return VoidPromise.rejected('TypeError: Writer has no associated stream')
	}
	mut stream := writer.stream_
	return stream.close_internal()
}

pub fn (mut writer WritableStreamDefaultWriter) abort(reason Value) &VoidPromise {
	if writer.released_ || isnil(writer.stream_) {
		return VoidPromise.rejected('TypeError: Writer has no associated stream')
	}
	mut stream := writer.stream_
	return stream.abort_internal(reason)
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
		writer.ready_ = VoidPromise.rejected('TypeError: Writer was released')
	}
	if writer.closed_.state() == .pending {
		mut closed := writer.closed_
		closed.reject('TypeError: Writer was released')
	} else {
		writer.closed_ = VoidPromise.rejected('TypeError: Writer was released')
	}
}
