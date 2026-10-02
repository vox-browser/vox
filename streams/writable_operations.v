// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Direct translations of writable-stream object slots and abstract operations.
module streams

import webidl

pub fn (mut stream WritableStream) transfer_steps() !&WritableStream {
	return stream.transfer()
}

pub fn (mut stream WritableStream) transfer_receiving_steps(mut source WritableStream) ! {
	proxy := source.transfer()!
	stream = *proxy
	if !isnil(stream.controller_) {
		stream.controller_.stream_ = &stream
	}
}

pub fn (mut stream WritableStream) set_backpressure(value bool) {
	stream.backpressure_ = value
}

pub fn (stream &WritableStream) close_request() ?&VoidPromise {
	if isnil(stream.close_request_) {
		return none
	}
	return stream.close_request_
}

pub fn (mut stream WritableStream) set_close_request(request ?&VoidPromise) {
	stream.close_request_ = request or { unsafe { nil } }
}

pub fn (stream &WritableStream) in_flight_write_request() ?&VoidPromise {
	if isnil(stream.in_flight_write_request_) {
		return none
	}
	return stream.in_flight_write_request_
}

pub fn (mut stream WritableStream) set_in_flight_write_request(request ?&VoidPromise) {
	stream.in_flight_write_request_ = request or { unsafe { nil } }
}

pub fn (stream &WritableStream) in_flight_close_request() ?&VoidPromise {
	if isnil(stream.in_flight_close_request_) {
		return none
	}
	return stream.in_flight_close_request_
}

pub fn (mut stream WritableStream) set_in_flight_close_request(request ?&VoidPromise) {
	stream.in_flight_close_request_ = request or { unsafe { nil } }
}

pub fn (stream &WritableStream) pending_abort_request() ?&VoidPromise {
	if isnil(stream.pending_abort_request_) {
		return none
	}
	return stream.pending_abort_request_
}

pub fn (mut stream WritableStream) set_pending_abort_request(request ?&VoidPromise) {
	stream.pending_abort_request_ = request or { unsafe { nil } }
}

pub fn (mut stream WritableStream) set_state(value WritableStreamState) {
	stream.state_ = value
}

pub fn (mut stream WritableStream) set_stored_error(reason string) {
	stream.stored_error_ = reason
	stream.stored_error_value_ = webidl.string_value(reason)
}

pub fn (mut stream WritableStream) set_writer(writer ?&WritableStreamDefaultWriter) {
	stream.writer_ = writer or { unsafe { nil } }
}

pub fn (mut stream WritableStream) set_controller(controller ?&WritableStreamDefaultController) {
	stream.controller_ = controller or { unsafe { nil } }
}

pub fn (stream &WritableStream) write_requests() []&VoidPromise {
	return stream.write_requests_.values()
}

pub fn (_ &WritableStream) primary_interface() string {
	return 'WritableStream'
}

pub fn (mut controller WritableStreamDefaultController) abort_steps(reason Value) &VoidPromise {
	mut native := controller.abort_steps_promise(reason)
	return void_promise_from_webidl(controller.stream_.realm_, mut native)
}

fn (mut controller WritableStreamDefaultController) abort_steps_promise(reason Value) &webidl.Promise {
	mut stream := controller.stream_
	result := stream.perform_abort(reason)
	writable_stream_default_controller_clear_algorithms(mut controller)
	return result
}

pub fn (mut controller WritableStreamDefaultController) error_steps() {
	controller.stream_.queue_.reset()
}

pub fn (mut controller WritableStreamDefaultController) set_signal(signal &AbortSignal) {
	controller.signal_ = signal
}

pub fn (controller &WritableStreamDefaultController) abort_algorithm() ?AbortAlgorithm {
	return controller.stream_.abort_algorithm_
}

pub fn (mut controller WritableStreamDefaultController) set_abort_algorithm(value ?AbortAlgorithm) {
	controller.stream_.abort_algorithm_ = value
}

pub fn (controller &WritableStreamDefaultController) close_algorithm() ?CloseAlgorithm {
	return controller.stream_.close_algorithm_
}

pub fn (mut controller WritableStreamDefaultController) set_close_algorithm(value ?CloseAlgorithm) {
	controller.stream_.close_algorithm_ = value
}

pub fn (controller &WritableStreamDefaultController) queue() []ValueWithSize {
	return controller.stream_.queue_.queue_.values()
}

pub fn (controller &WritableStreamDefaultController) queue_total_size() f64 {
	return controller.stream_.queue_.total_size_
}

pub fn (mut controller WritableStreamDefaultController) set_queue_total_size(value f64) {
	controller.stream_.queue_.total_size_ = value
}

pub fn (controller &WritableStreamDefaultController) started() bool {
	return controller.stream_.started_
}

pub fn (mut controller WritableStreamDefaultController) set_started(value bool) {
	controller.stream_.started_ = value
}

pub fn (controller &WritableStreamDefaultController) strategy_hwm() f64 {
	return controller.stream_.high_water_mark_
}

pub fn (mut controller WritableStreamDefaultController) set_strategy_hwm(value f64) {
	controller.stream_.high_water_mark_ = value
}

pub fn (controller &WritableStreamDefaultController) strategy_size_algorithm() SizeAlgorithm {
	return controller.stream_.size_algorithm_
}

pub fn (mut controller WritableStreamDefaultController) set_strategy_size_algorithm(value SizeAlgorithm) {
	controller.stream_.size_algorithm_ = value
	controller.stream_.size_value_algorithm_ = none
}

pub fn (controller &WritableStreamDefaultController) stream() &WritableStream {
	return controller.stream_
}

pub fn (mut controller WritableStreamDefaultController) set_stream(stream &WritableStream) {
	controller.stream_ = stream
}

pub fn (controller &WritableStreamDefaultController) write_algorithm() ?WriteAlgorithm {
	return controller.stream_.write_algorithm_
}

pub fn (mut controller WritableStreamDefaultController) set_write_algorithm(value ?WriteAlgorithm) {
	controller.stream_.write_algorithm_ = value
}

pub fn (writer &WritableStreamDefaultWriter) closed_promise() &VoidPromise {
	return writer.closed_
}

pub fn (mut writer WritableStreamDefaultWriter) set_closed_promise(promise &VoidPromise) {
	writer.closed_ = promise
}

pub fn (writer &WritableStreamDefaultWriter) ready_promise() &VoidPromise {
	return writer.ready_
}

pub fn (mut writer WritableStreamDefaultWriter) set_ready_promise(promise &VoidPromise) {
	writer.ready_ = promise
}

pub fn (writer &WritableStreamDefaultWriter) stream() ?&WritableStream {
	if writer.released_ || isnil(writer.stream_) {
		return none
	}
	return writer.stream_
}

pub fn (mut writer WritableStreamDefaultWriter) set_stream(stream ?&WritableStream) {
	writer.stream_ = stream or { unsafe { nil } }
	writer.released_ = stream == none
}

pub fn acquire_writable_stream_default_writer(mut stream WritableStream) !&WritableStreamDefaultWriter {
	return stream.get_writer()
}

pub fn create_writable_stream(start StartAlgorithm, write WriteAlgorithm, close CloseAlgorithm, abort AbortAlgorithm, high_water_mark f64, size SizeAlgorithm) !&WritableStream {
	return WritableStream.construct_impl(UnderlyingSink{
		start: start
		write: write
		close: close
		abort: abort
	}, QueuingStrategy{
		high_water_mark: high_water_mark
		size: size
	})
}

pub fn initialize_writable_stream(mut stream WritableStream) {
	stream.state_ = .writable
	stream.stored_error_ = ''
	stream.stored_error_value_ = none
	stream.writer_ = unsafe { nil }
	stream.controller_ = unsafe { nil }
	stream.in_flight_write_request_ = unsafe { nil }
	stream.close_request_ = unsafe { nil }
	stream.in_flight_close_request_ = unsafe { nil }
	stream.pending_abort_request_ = unsafe { nil }
	stream.pending_abort_reason_ = undefined_value()
	stream.pending_abort_erroring_ = false
	stream.write_requests_.clear()
	stream.backpressure_ = false
}

pub fn is_writable_stream_locked(stream &WritableStream) bool {
	return stream.locked()
}

pub fn set_up_writable_stream_default_writer(mut writer WritableStreamDefaultWriter, mut stream WritableStream) ! {
	created := WritableStreamDefaultWriter.create(stream.realm_, mut stream)!
	writer = *created
}

pub fn writable_stream_abort(mut stream WritableStream, reason Value) &VoidPromise {
	return stream.abort_internal(reason)
}

pub fn writable_stream_close(mut stream WritableStream) &VoidPromise {
	return stream.close_internal()
}

pub fn writable_stream_add_write_request(mut stream WritableStream) &VoidPromise {
	request := VoidPromise.pending_in(stream.realm_)
	stream.write_requests_.append(request)
	return request
}

pub fn writable_stream_close_queued_or_in_flight(stream &WritableStream) bool {
	return !isnil(stream.close_request_) || !isnil(stream.in_flight_close_request_)
}

pub fn writable_stream_deal_with_rejection(mut stream WritableStream, reason Value) {
	if stream.state_ == .writable {
		stream.start_erroring_value(stream_value_to_webidl(reason), reason.description())
	} else if stream.state_ == .erroring {
		stream.finish_erroring()
	}
}

pub fn writable_stream_finish_erroring(mut stream WritableStream) {
	stream.finish_erroring()
}

pub fn writable_stream_finish_in_flight_close(mut stream WritableStream) {
	if !isnil(stream.in_flight_close_request_) {
		mut request := stream.in_flight_close_request_
		request.resolve()
		stream.in_flight_close_request_ = unsafe { nil }
	}
	if stream.state_ == .erroring {
		stream.stored_error_ = ''
		stream.stored_error_value_ = none
		if !isnil(stream.pending_abort_request_) {
			mut abort_request := stream.pending_abort_request_
			abort_request.resolve()
			stream.pending_abort_request_ = unsafe { nil }
		}
	}
	stream.state_ = .closed
	if !isnil(stream.writer_) {
		mut closed := stream.writer_.closed_
		closed.resolve()
	}
}

pub fn writable_stream_finish_in_flight_close_with_error(mut stream WritableStream, reason Value) {
	if !isnil(stream.in_flight_close_request_) {
		mut request := stream.in_flight_close_request_
		request.reject_value(stream_value_to_webidl(reason))
		stream.in_flight_close_request_ = unsafe { nil }
	}
	if !isnil(stream.pending_abort_request_) {
		mut abort_request := stream.pending_abort_request_
		abort_request.reject_value(stream_value_to_webidl(reason))
		stream.pending_abort_request_ = unsafe { nil }
	}
	writable_stream_deal_with_rejection(mut stream, reason)
}

pub fn writable_stream_finish_in_flight_write(mut stream WritableStream) {
	if !isnil(stream.in_flight_write_request_) {
		mut request := stream.in_flight_write_request_
		request.resolve()
		stream.in_flight_write_request_ = unsafe { nil }
	}
}

pub fn writable_stream_finish_in_flight_write_with_error(mut stream WritableStream, reason Value) {
	if !isnil(stream.in_flight_write_request_) {
		mut request := stream.in_flight_write_request_
		request.reject_value(stream_value_to_webidl(reason))
		stream.in_flight_write_request_ = unsafe { nil }
	}
	writable_stream_deal_with_rejection(mut stream, reason)
}

pub fn writable_stream_has_operation_marked_in_flight(stream &WritableStream) bool {
	return !isnil(stream.in_flight_write_request_) || !isnil(stream.in_flight_close_request_)
}

pub fn writable_stream_mark_close_request_in_flight(mut stream WritableStream) {
	stream.in_flight_close_request_ = stream.close_request_
	stream.close_request_ = unsafe { nil }
}

pub fn writable_stream_mark_first_write_request_in_flight(mut stream WritableStream) {
	if stream.write_requests_.len == 0 {
		return
	}
	stream.in_flight_write_request_ = stream.write_requests_.shift() or { return }
}

pub fn writable_stream_reject_close_and_closed_promise_if_needed(mut stream WritableStream) {
	if !isnil(stream.close_request_) {
		mut request := stream.close_request_
		request.reject_value(stream.stored_error_value())
		stream.close_request_ = unsafe { nil }
	}
	if !isnil(stream.writer_) {
		mut closed := stream.writer_.closed_
		closed.reject_value(stream.stored_error_value())
		mut native_closed := closed.as_webidl_promise()
		webidl.mark_promise_as_handled(mut native_closed)
	}
	if !isnil(stream.pipe_source_) {
		mut source := stream.pipe_source_
		pump_readable_pipe(mut source)
	}
}

pub fn writable_stream_start_erroring(mut stream WritableStream, reason Value) {
	stream.start_erroring_value(stream_value_to_webidl(reason), reason.description())
}

pub fn writable_stream_update_backpressure(mut stream WritableStream, backpressure bool) {
	changed := backpressure != stream.backpressure_
	if !isnil(stream.writer_) && changed {
		mut writer := stream.writer_
		if backpressure {
			writer.ready_ = VoidPromise.pending_in(writer.ready_promise_realm())
		} else {
			mut ready := writer.ready_
			ready.resolve()
		}
	}
	stream.set_backpressure(backpressure)
	if changed && !backpressure && !isnil(stream.pipe_source_) {
		mut source := stream.pipe_source_
		pump_readable_pipe(mut source)
	}
}

pub fn writable_stream_default_writer_abort(mut writer WritableStreamDefaultWriter, reason Value) &VoidPromise {
	return writer.abort(reason)
}

pub fn writable_stream_default_writer_close(mut writer WritableStreamDefaultWriter) &VoidPromise {
	return writer.close()
}

pub fn writable_stream_default_writer_close_with_error_propagation(mut writer WritableStreamDefaultWriter) &VoidPromise {
	if writer.released_ || isnil(writer.stream_) {
		return VoidPromise.rejected('TypeError: Writer has no associated stream')
	}
	if writable_stream_close_queued_or_in_flight(writer.stream_) || writer.stream_.state_ == .closed {
		return VoidPromise.fulfilled()
	}
	if writer.stream_.state_ == .errored {
		return VoidPromise.rejected_value_in(writer.closed_promise_realm(), writer.stream_.stored_error_value())
	}
	return writer.close()
}

pub fn writable_stream_default_writer_ensure_closed_promise_rejected(mut writer WritableStreamDefaultWriter, reason Value) {
	if writer.closed_.state() == .pending {
		mut closed := writer.closed_
		closed.reject_value(stream_value_to_webidl(reason))
	} else {
		writer.closed_ = VoidPromise.rejected_value_in(writer.closed_promise_realm(), stream_value_to_webidl(reason))
	}
}

pub fn writable_stream_default_writer_ensure_ready_promise_rejected(mut writer WritableStreamDefaultWriter, reason Value) {
	if writer.ready_.state() == .pending {
		mut ready := writer.ready_
		ready.reject_value(stream_value_to_webidl(reason))
	} else {
		writer.ready_ = VoidPromise.rejected_value_in(writer.ready_promise_realm(), stream_value_to_webidl(reason))
	}
}

pub fn writable_stream_default_writer_get_desired_size(writer &WritableStreamDefaultWriter) ?f64 {
	return writer.desired_size()
}

pub fn writable_stream_default_writer_release(mut writer WritableStreamDefaultWriter) {
	writer.release_lock()
}

pub fn writable_stream_default_writer_write(mut writer WritableStreamDefaultWriter, chunk Value) &VoidPromise {
	return writer.write(chunk)
}

pub fn set_up_writable_stream_default_controller(mut stream WritableStream, mut controller WritableStreamDefaultController, start StartAlgorithm, write WriteAlgorithm, close CloseAlgorithm, abort AbortAlgorithm, high_water_mark f64, size SizeAlgorithm) ! {
	set_up_writable_stream_default_controller_slots(mut stream, mut controller, write, close, abort, high_water_mark, size)!
	stream.start_underlying_sink(UnderlyingSink{ start: start })!
}

fn set_up_writable_stream_default_controller_slots(mut stream WritableStream, mut controller WritableStreamDefaultController, write WriteAlgorithm, close CloseAlgorithm, abort AbortAlgorithm, high_water_mark f64, size SizeAlgorithm) ! {
	if high_water_mark < 0 {
		return error('RangeError: highWaterMark must be non-negative')
	}
	controller.stream_ = &stream
	controller.signal_ = AbortSignal.create()
	stream.controller_ = &controller
	stream.queue_.reset()
	stream.started_ = false
	stream.high_water_mark_ = high_water_mark
	stream.size_algorithm_ = size
	stream.write_algorithm_ = write
	stream.close_algorithm_ = close
	stream.abort_algorithm_ = abort
	backpressure := writable_stream_default_controller_get_backpressure(controller)
	writable_stream_update_backpressure(mut stream, backpressure)

}

pub fn set_up_writable_stream_default_controller_from_underlying_sink(mut stream WritableStream, sink UnderlyingSink, high_water_mark f64, size SizeAlgorithm) ! {
	mut controller := WritableStreamDefaultController{
		stream_: &stream
		signal_: AbortSignal.create()
	}
	set_up_writable_stream_default_controller_slots(mut stream, mut controller, sink.write or { no_op_write_algorithm }, sink.close or { no_op_close_algorithm }, sink.abort or { no_op_abort_algorithm }, high_water_mark, size)!
	stream.start_underlying_sink(sink)!
}

fn no_op_write_algorithm(_ Value) ! {}

fn no_op_close_algorithm() ! {}

fn no_op_abort_algorithm(_ Value) ! {}

pub fn writable_stream_default_controller_advance_queue_if_needed(mut controller WritableStreamDefaultController) {
	controller.stream_.process_queue()
}

pub fn writable_stream_default_controller_clear_algorithms(mut controller WritableStreamDefaultController) {
	controller.stream_.write_algorithm_ = none
	controller.stream_.close_algorithm_ = none
	controller.stream_.abort_algorithm_ = none
	controller.stream_.promise_write_algorithm_ = none
	controller.stream_.promise_close_algorithm_ = none
	controller.stream_.promise_abort_algorithm_ = none
	controller.stream_.size_algorithm_ = default_size_algorithm
	controller.stream_.size_value_algorithm_ = none
}

pub fn writable_stream_default_controller_close(mut controller WritableStreamDefaultController) {
	controller.stream_.queue_.enqueue_close_sentinel()
	controller.stream_.process_queue()
}

pub fn writable_stream_default_controller_error(mut controller WritableStreamDefaultController, reason Value) {
	if controller.stream_.state_ != .writable {
		return
	}
	writable_stream_default_controller_clear_algorithms(mut controller)
	controller.stream_.start_erroring_value(stream_value_to_webidl(reason), reason.description())
}

pub fn writable_stream_default_controller_error_if_needed(mut controller WritableStreamDefaultController, reason Value) {
	if controller.stream_.state_ == .writable {
		writable_stream_default_controller_error(mut controller, reason)
	}
}

pub fn writable_stream_default_controller_get_backpressure(controller &WritableStreamDefaultController) bool {
	return writable_stream_default_controller_get_desired_size(controller) <= 0
}

pub fn writable_stream_default_controller_get_chunk_size(mut controller WritableStreamDefaultController, chunk Value) !f64 {
	actual := writable_stream_default_controller_get_chunk_size_value(mut controller, chunk)!
	return actual.number_primitive() or { return error('RangeError: Chunk size must be a non-negative number') }
}

pub fn writable_stream_default_controller_get_chunk_size_value(mut controller WritableStreamDefaultController, chunk Value) !webidl.Value {
	return invoke_size_value_algorithm(controller.stream_.size_algorithm_, controller.stream_.size_value_algorithm_, chunk) or {
		writable_stream_default_controller_error_if_needed(mut controller, stream_value_from_webidl(webidl.exception_value(err)))
		return webidl.number_value(1)
	}
}

pub fn writable_stream_default_controller_get_desired_size(controller &WritableStreamDefaultController) f64 {
	return controller.stream_.high_water_mark_ - controller.stream_.queue_.total_size_
}

pub fn writable_stream_default_controller_process_close(mut controller WritableStreamDefaultController) {
	mut stream := controller.stream_
	writable_stream_mark_close_request_in_flight(mut stream)
	_ = stream.queue_.dequeue_value() or {
		writable_stream_finish_in_flight_close_with_error(mut stream, stream_value_from_webidl(webidl.exception_value(err)))
		return
	}
	assert stream.queue_.is_empty()
	mut close_result := stream.perform_close()
	writable_stream_default_controller_clear_algorithms(mut controller)
	webidl.react_to_promise(mut close_result, fn [mut stream] (_ webidl.Value) !webidl.Value {
		writable_stream_finish_in_flight_close(mut stream)
		return webidl.undefined_value()
	}, fn [mut stream] (reason webidl.Value) !webidl.Value {
		writable_stream_finish_in_flight_close_with_error(mut stream, stream_value_from_webidl(reason))
		return webidl.undefined_value()
	})
}

pub fn writable_stream_default_controller_process_write(mut controller WritableStreamDefaultController, chunk Value) {
	mut stream := controller.stream_
	writable_stream_mark_first_write_request_in_flight(mut stream)
	mut write_result := stream.perform_write(chunk)
	webidl.react_to_promise(mut write_result, fn [mut stream, chunk] (_ webidl.Value) !webidl.Value {
		stream.written_values_ << chunk
		writable_stream_finish_in_flight_write(mut stream)
		_ = stream.queue_.dequeue_value() or {
			mut controller := stream.controller_
			writable_stream_default_controller_error_if_needed(mut controller, stream_value_from_webidl(webidl.exception_value(err)))
			return webidl.undefined_value()
		}
		if !writable_stream_close_queued_or_in_flight(stream) && stream.state_ == .writable {
			stream.update_backpressure()
		}
		stream.process_queue()
		if !isnil(stream.pipe_source_) {
			mut source := stream.pipe_source_
			pump_readable_pipe(mut source)
		}
		return webidl.undefined_value()
	}, fn [mut stream] (reason webidl.Value) !webidl.Value {
		if stream.state_ == .writable {
			mut controller := stream.controller_
			writable_stream_default_controller_clear_algorithms(mut controller)
		}
		writable_stream_finish_in_flight_write_with_error(mut stream, stream_value_from_webidl(reason))
		return webidl.undefined_value()
	})
}

pub fn writable_stream_default_controller_write(mut controller WritableStreamDefaultController, chunk Value, chunk_size f64) ! {
	writable_stream_default_controller_write_value(mut controller, chunk, webidl.number_value(chunk_size))!
}

pub fn writable_stream_default_controller_write_value(mut controller WritableStreamDefaultController, chunk Value, chunk_size webidl.Value) ! {
	controller.stream_.queue_.enqueue_value_with_size_value(chunk, chunk_size) or {
		writable_stream_default_controller_error_if_needed(mut controller, stream_value_from_webidl(webidl.exception_value(err)))
		return err
	}
	if !writable_stream_close_queued_or_in_flight(controller.stream_) && controller.stream_.state_ == .writable {
		controller.stream_.update_backpressure()
	}
	controller.stream_.process_queue()
}
