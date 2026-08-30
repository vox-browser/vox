// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Direct translations of writable-stream object slots and abstract operations.
module streams

const close_sentinel_text = '__libweb_stream_close_sentinel__'

pub fn UnderlyingSink.from_value(value Value) !UnderlyingSink {
	if value.kind in [.undefined, .null_] {
		return UnderlyingSink{}
	}
	return error('TypeError: UnderlyingSink callbacks must use the typed V boundary')
}

pub fn (mut stream WritableStream) transfer_steps() !&WritableStream {
	return stream.transfer()
}

pub fn (mut stream WritableStream) transfer_receiving_steps(mut source WritableStream) ! {
	proxy := source.transfer()!
	stream.owner_kind_ = proxy.owner_kind_
	stream.transfer_destination_ = proxy.transfer_destination_
}

pub fn (mut stream WritableStream) set_backpressure(value bool) {
	if stream.backpressure_ == value {
		return
	}
	stream.backpressure_ = value
	if !isnil(stream.writer_) {
		mut writer := stream.writer_
		if value {
			writer.ready_ = VoidPromise.pending()
		} else {
			mut ready := writer.ready_
			ready.resolve()
		}
	}
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
}

pub fn (mut stream WritableStream) set_writer(writer ?&WritableStreamDefaultWriter) {
	stream.writer_ = writer or { unsafe { nil } }
}

pub fn (mut stream WritableStream) set_controller(controller &WritableStreamDefaultController) {
	stream.controller_ = controller
}

pub fn (stream &WritableStream) write_requests() []&VoidPromise {
	return stream.write_requests_.clone()
}

pub fn (_ &WritableStream) primary_interface() string {
	return 'WritableStream'
}

pub fn (mut controller WritableStreamDefaultController) abort_steps(reason Value) &VoidPromise {
	mut stream := controller.stream_
	return stream.abort_internal(reason)
}

pub fn (mut controller WritableStreamDefaultController) error_steps() {
	mut stream := controller.stream_
	stream.start_erroring(stream.stored_error_)
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
	return controller.stream_.queue_.queue_.clone()
}

pub fn (controller &WritableStreamDefaultController) queue_total_size() f64 {
	return controller.stream_.queue_.total_size_
}

pub fn (mut controller WritableStreamDefaultController) set_queue_total_size(value f64) {
	controller.stream_.queue_.total_size_ = if value < 0 { 0 } else { value }
}

pub fn (controller &WritableStreamDefaultController) started() bool {
	return controller.stream_.state_ != .writable || controller.stream_.controller_ == controller
}

pub fn (_ &WritableStreamDefaultController) set_started(_ bool) {
	// Start callbacks settle synchronously at the standalone boundary.
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

pub fn create_close_sentinel() Value {
	return string_value(close_sentinel_text)
}

pub fn is_close_sentinel(value Value) bool {
	return value.kind == .string_ && value.text == close_sentinel_text
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
	stream.queue_.reset()
	stream.writer_ = unsafe { nil }
	stream.close_queued_ = false
	stream.in_flight_write_ = false
	stream.in_flight_close_ = false
	stream.write_requests_.clear()
}

pub fn is_writable_stream_locked(stream &WritableStream) bool {
	return stream.locked()
}

pub fn set_up_writable_stream_default_writer(mut writer WritableStreamDefaultWriter, mut stream WritableStream) ! {
	created := stream.get_writer()!
	writer = *created
}

pub fn writable_stream_abort(mut stream WritableStream, reason Value) &VoidPromise {
	return stream.abort_internal(reason)
}

pub fn writable_stream_close(mut stream WritableStream) &VoidPromise {
	return stream.close_internal()
}

pub fn writable_stream_add_write_request(mut stream WritableStream) &VoidPromise {
	request := VoidPromise.pending()
	stream.write_requests_ << request
	return request
}

pub fn writable_stream_close_queued_or_in_flight(stream &WritableStream) bool {
	return stream.close_queued_ || stream.in_flight_close_
}

pub fn writable_stream_deal_with_rejection(mut stream WritableStream, reason Value) {
	if stream.state_ == .writable {
		stream.start_erroring(reason.description())
	} else if stream.state_ == .erroring {
		stream.finish_erroring()
	}
}

pub fn writable_stream_finish_erroring(mut stream WritableStream) {
	stream.finish_erroring()
}

pub fn writable_stream_finish_in_flight_close(mut stream WritableStream) {
	stream.in_flight_close_ = false
	if !isnil(stream.in_flight_close_request_) {
		mut request := stream.in_flight_close_request_
		request.resolve()
		stream.in_flight_close_request_ = unsafe { nil }
	}
	stream.state_ = .closed
}

pub fn writable_stream_finish_in_flight_close_with_error(mut stream WritableStream, reason Value) {
	stream.in_flight_close_ = false
	if !isnil(stream.in_flight_close_request_) {
		mut request := stream.in_flight_close_request_
		request.reject(reason.description())
		stream.in_flight_close_request_ = unsafe { nil }
	}
	stream.start_erroring(reason.description())
}

pub fn writable_stream_finish_in_flight_write(mut stream WritableStream) {
	stream.in_flight_write_ = false
	if !isnil(stream.in_flight_write_request_) {
		mut request := stream.in_flight_write_request_
		request.resolve()
		stream.in_flight_write_request_ = unsafe { nil }
	}
	stream.process_queue()
}

pub fn writable_stream_finish_in_flight_write_with_error(mut stream WritableStream, reason Value) {
	stream.in_flight_write_ = false
	if !isnil(stream.in_flight_write_request_) {
		mut request := stream.in_flight_write_request_
		request.reject(reason.description())
		stream.in_flight_write_request_ = unsafe { nil }
	}
	stream.start_erroring(reason.description())
}

pub fn writable_stream_has_operation_marked_in_flight(stream &WritableStream) bool {
	return stream.in_flight_write_ || stream.in_flight_close_
}

pub fn writable_stream_mark_close_request_in_flight(mut stream WritableStream) {
	stream.in_flight_close_ = true
	stream.in_flight_close_request_ = stream.close_request_
	stream.close_request_ = unsafe { nil }
}

pub fn writable_stream_mark_first_write_request_in_flight(mut stream WritableStream) {
	if stream.write_requests_.len == 0 {
		return
	}
	stream.in_flight_write_ = true
	stream.in_flight_write_request_ = stream.write_requests_[0]
	stream.write_requests_.delete(0)
}

pub fn writable_stream_reject_close_and_closed_promise_if_needed(mut stream WritableStream) {
	if !isnil(stream.close_request_) {
		mut request := stream.close_request_
		request.reject(stream.stored_error_)
		stream.close_request_ = unsafe { nil }
	}
	if !isnil(stream.writer_) {
		mut closed := stream.writer_.closed_
		closed.reject(stream.stored_error_)
	}
}

pub fn writable_stream_start_erroring(mut stream WritableStream, reason Value) {
	stream.start_erroring(reason.description())
}

pub fn writable_stream_update_backpressure(mut stream WritableStream, backpressure bool) {
	stream.set_backpressure(backpressure)
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
	if writer.stream_.state_ in [.errored, .erroring] {
		return VoidPromise.rejected(writer.stream_.stored_error_)
	}
	return writer.close()
}

pub fn writable_stream_default_writer_ensure_closed_promise_rejected(mut writer WritableStreamDefaultWriter, reason Value) {
	if writer.closed_.state() == .pending {
		mut closed := writer.closed_
		closed.reject(reason.description())
	} else {
		writer.closed_ = VoidPromise.rejected(reason.description())
	}
}

pub fn writable_stream_default_writer_ensure_ready_promise_rejected(mut writer WritableStreamDefaultWriter, reason Value) {
	if writer.ready_.state() == .pending {
		mut ready := writer.ready_
		ready.reject(reason.description())
	} else {
		writer.ready_ = VoidPromise.rejected(reason.description())
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
	if high_water_mark < 0 {
		return error('RangeError: highWaterMark must be non-negative')
	}
	controller.stream_ = &stream
	controller.signal_ = AbortSignal.create()
	stream.controller_ = &controller
	stream.high_water_mark_ = high_water_mark
	stream.size_algorithm_ = size
	stream.write_algorithm_ = write
	stream.close_algorithm_ = close
	stream.abort_algorithm_ = abort
	start() or {
		stream.start_erroring(err.msg())
		return err
	}
	stream.update_backpressure()
}

pub fn set_up_writable_stream_default_controller_from_underlying_sink(mut stream WritableStream, sink UnderlyingSink, high_water_mark f64, size SizeAlgorithm) ! {
	mut controller := WritableStreamDefaultController{
		stream_: &stream
		signal_: AbortSignal.create()
	}
	set_up_writable_stream_default_controller(mut stream, mut controller, sink.start or { no_op_start_algorithm }, sink.write or { no_op_write_algorithm }, sink.close or { no_op_close_algorithm }, sink.abort or { no_op_abort_algorithm }, high_water_mark, size)!
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
}

pub fn writable_stream_default_controller_close(mut controller WritableStreamDefaultController) {
	controller.stream_.finish_close()
}

pub fn writable_stream_default_controller_error(mut controller WritableStreamDefaultController, reason Value) {
	controller.error(reason.description())
}

pub fn writable_stream_default_controller_error_if_needed(mut controller WritableStreamDefaultController, reason Value) {
	if controller.stream_.state_ == .writable {
		controller.error(reason.description())
	}
}

pub fn writable_stream_default_controller_get_backpressure(controller &WritableStreamDefaultController) bool {
	return controller.stream_.backpressure_
}

pub fn writable_stream_default_controller_get_chunk_size(controller &WritableStreamDefaultController, chunk Value) !f64 {
	return controller.stream_.size_algorithm_(chunk)
}

pub fn writable_stream_default_controller_get_desired_size(controller &WritableStreamDefaultController) f64 {
	return controller.stream_.desired_size_internal() or { 0.0 }
}

pub fn writable_stream_default_controller_process_close(mut controller WritableStreamDefaultController) {
	controller.stream_.finish_close()
}

pub fn writable_stream_default_controller_process_write(mut controller WritableStreamDefaultController, chunk Value) {
	controller.stream_.perform_write(chunk) or {
		controller.stream_.start_erroring(err.msg())
		return
	}
}

pub fn writable_stream_default_controller_write(mut controller WritableStreamDefaultController, chunk Value, chunk_size f64) ! {
	controller.stream_.queue_.enqueue_value_with_size(chunk, chunk_size)!
	controller.stream_.update_backpressure()
	controller.stream_.process_queue()
}
