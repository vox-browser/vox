// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Direct controller entry points from ReadableStreamOperations. Controller
// slots live on ReadableStream in this compact object model, so accessors below
// deliberately project and mutate that single canonical state.
module streams

pub fn (mut controller ReadableStreamDefaultController) cancel_steps(reason Value) &VoidPromise {
	mut stream := controller.stream_
	return stream.cancel_internal(reason)
}

pub fn (mut controller ReadableStreamDefaultController) pull_steps() &ReadPromise {
	mut stream := controller.stream_
	return stream.read_internal()
}

pub fn (_ &ReadableStreamDefaultController) release_steps() {}

pub fn (controller &ReadableStreamDefaultController) cancel_algorithm() ?CancelAlgorithm {
	return controller.stream_.cancel_algorithm_
}

pub fn (mut controller ReadableStreamDefaultController) set_cancel_algorithm(value ?CancelAlgorithm) {
	controller.stream_.cancel_algorithm_ = value
}

pub fn (controller &ReadableStreamDefaultController) close_requested() bool {
	return controller.stream_.close_requested_
}

pub fn (mut controller ReadableStreamDefaultController) set_close_requested(value bool) {
	controller.stream_.close_requested_ = value
}

pub fn (controller &ReadableStreamDefaultController) pull_again() bool {
	return controller.stream_.pull_again_
}

pub fn (mut controller ReadableStreamDefaultController) set_pull_again(value bool) {
	controller.stream_.pull_again_ = value
}

pub fn (controller &ReadableStreamDefaultController) pull_algorithm() ?PullAlgorithm {
	return controller.stream_.pull_algorithm_
}

pub fn (mut controller ReadableStreamDefaultController) set_pull_algorithm(value ?PullAlgorithm) {
	controller.stream_.pull_algorithm_ = value
}

pub fn (controller &ReadableStreamDefaultController) pulling() bool {
	return controller.stream_.pulling_
}

pub fn (mut controller ReadableStreamDefaultController) set_pulling(value bool) {
	controller.stream_.pulling_ = value
}

pub fn (controller &ReadableStreamDefaultController) queue() []ValueWithSize {
	return controller.stream_.queue_.queue_.clone()
}

pub fn (controller &ReadableStreamDefaultController) queue_total_size() f64 {
	return controller.stream_.queue_.total_size_
}

pub fn (mut controller ReadableStreamDefaultController) set_queue_total_size(value f64) {
	controller.stream_.queue_.total_size_ = if value < 0 { 0 } else { value }
}

pub fn (controller &ReadableStreamDefaultController) started() bool {
	return controller.stream_.started_
}

pub fn (mut controller ReadableStreamDefaultController) set_started(value bool) {
	controller.stream_.started_ = value
}

pub fn (controller &ReadableStreamDefaultController) strategy_hwm() f64 {
	return controller.stream_.high_water_mark_
}

pub fn (mut controller ReadableStreamDefaultController) set_strategy_hwm(value f64) {
	controller.stream_.high_water_mark_ = value
}

pub fn (controller &ReadableStreamDefaultController) strategy_size_algorithm() SizeAlgorithm {
	return controller.stream_.size_algorithm_
}

pub fn (mut controller ReadableStreamDefaultController) set_strategy_size_algorithm(value SizeAlgorithm) {
	controller.stream_.size_algorithm_ = value
}

pub fn (controller &ReadableStreamDefaultController) stream() &ReadableStream {
	return controller.stream_
}

pub fn (mut controller ReadableStreamDefaultController) set_stream(stream &ReadableStream) {
	controller.stream_ = stream
}

pub fn (mut controller ReadableByteStreamController) cancel_steps(reason Value) &VoidPromise {
	mut stream := controller.stream_
	return stream.cancel_internal(reason)
}

pub fn (mut controller ReadableByteStreamController) pull_steps() &ReadPromise {
	mut stream := controller.stream_
	return stream.read_internal()
}

pub fn (mut controller ReadableByteStreamController) release_steps() {
	for mut descriptor in controller.pending_pull_intos_ {
		descriptor.minimum_fill = 1
	}
}

pub fn (mut controller ReadableByteStreamController) set_byob_request(request ?&ReadableStreamBYOBRequest) {
	controller.stream_.byob_request_ = request or { unsafe { nil } }
}

pub fn (controller &ReadableByteStreamController) raw_byob_request() ?&ReadableStreamBYOBRequest {
	if isnil(controller.stream_.byob_request_) {
		return none
	}
	return controller.stream_.byob_request_
}

pub fn (controller &ReadableByteStreamController) auto_allocate_chunk_size() ?u64 {
	return controller.stream_.auto_allocate_size_
}

pub fn (mut controller ReadableByteStreamController) set_auto_allocate_chunk_size(value ?u64) {
	controller.stream_.auto_allocate_size_ = value
}

pub fn (controller &ReadableByteStreamController) cancel_algorithm() ?CancelAlgorithm {
	return controller.stream_.cancel_algorithm_
}

pub fn (mut controller ReadableByteStreamController) set_cancel_algorithm(value ?CancelAlgorithm) {
	controller.stream_.cancel_algorithm_ = value
}

pub fn (controller &ReadableByteStreamController) close_requested() bool {
	return controller.stream_.close_requested_
}

pub fn (mut controller ReadableByteStreamController) set_close_requested(value bool) {
	controller.stream_.close_requested_ = value
}

pub fn (controller &ReadableByteStreamController) pull_again() bool {
	return controller.stream_.pull_again_
}

pub fn (mut controller ReadableByteStreamController) set_pull_again(value bool) {
	controller.stream_.pull_again_ = value
}

pub fn (controller &ReadableByteStreamController) pull_algorithm() ?PullAlgorithm {
	return controller.stream_.pull_algorithm_
}

pub fn (mut controller ReadableByteStreamController) set_pull_algorithm(value ?PullAlgorithm) {
	controller.stream_.pull_algorithm_ = value
}

pub fn (controller &ReadableByteStreamController) pulling() bool {
	return controller.stream_.pulling_
}

pub fn (mut controller ReadableByteStreamController) set_pulling(value bool) {
	controller.stream_.pulling_ = value
}

pub fn (controller &ReadableByteStreamController) pending_pull_intos() []PullIntoDescriptor {
	return controller.pending_pull_intos_.clone()
}

pub fn (controller &ReadableByteStreamController) queue() []ValueWithSize {
	return controller.stream_.queue_.queue_.clone()
}

pub fn (controller &ReadableByteStreamController) queue_total_size() f64 {
	return controller.stream_.queue_.total_size_
}

pub fn (mut controller ReadableByteStreamController) set_queue_total_size(value f64) {
	controller.stream_.queue_.total_size_ = if value < 0 { 0 } else { value }
}

pub fn (controller &ReadableByteStreamController) started() bool {
	return controller.stream_.started_
}

pub fn (mut controller ReadableByteStreamController) set_started(value bool) {
	controller.stream_.started_ = value
}

pub fn (controller &ReadableByteStreamController) strategy_hwm() f64 {
	return controller.stream_.high_water_mark_
}

pub fn (mut controller ReadableByteStreamController) set_strategy_hwm(value f64) {
	controller.stream_.high_water_mark_ = value
}

pub fn (controller &ReadableByteStreamController) stream() &ReadableStream {
	return controller.stream_
}

pub fn (mut controller ReadableByteStreamController) set_stream(stream &ReadableStream) {
	controller.stream_ = stream
}

pub fn readable_stream_default_controller_call_pull_if_needed(mut controller ReadableStreamDefaultController) {
	controller.stream_.call_pull_if_needed()
}

pub fn readable_stream_default_controller_should_call_pull(controller &ReadableStreamDefaultController) bool {
	stream := controller.stream_
	if !stream.started_ || stream.state_ != .readable || stream.close_requested_ {
		return false
	}
	desired := stream.desired_size() or { return false }
	return desired > 0 || stream.pending_reads_.len > 0
}

pub fn readable_stream_default_controller_clear_algorithms(mut controller ReadableStreamDefaultController) {
	controller.stream_.pull_algorithm_ = none
	controller.stream_.cancel_algorithm_ = none
	controller.stream_.size_algorithm_ = default_size_algorithm
}

pub fn readable_stream_default_controller_close(mut controller ReadableStreamDefaultController) {
	controller.close() or {}
}

pub fn readable_stream_default_controller_enqueue(mut controller ReadableStreamDefaultController, chunk Value) ! {
	controller.enqueue(chunk)!
}

pub fn readable_stream_default_controller_error(mut controller ReadableStreamDefaultController, reason Value) {
	controller.error(reason.description())
}

pub fn readable_stream_default_controller_get_desired_size(controller &ReadableStreamDefaultController) ?f64 {
	return controller.desired_size()
}

pub fn readable_stream_default_controller_has_backpressure(controller &ReadableStreamDefaultController) bool {
	desired := controller.desired_size() or { return false }
	return desired <= 0
}

pub fn readable_stream_default_controller_can_close_or_enqueue(controller &ReadableStreamDefaultController) bool {
	return controller.stream_.state_ == .readable && !controller.stream_.close_requested_
}

pub fn set_up_readable_stream_default_controller(mut stream ReadableStream, mut controller ReadableStreamDefaultController, start StartAlgorithm, pull PullAlgorithm, cancel CancelAlgorithm, high_water_mark f64, size SizeAlgorithm) ! {
	if high_water_mark < 0 {
		return error('RangeError: highWaterMark must be non-negative')
	}
	controller.stream_ = &stream
	stream.default_controller_ = &controller
	stream.byte_controller_ = unsafe { nil }
	stream.byte_stream_ = false
	stream.high_water_mark_ = high_water_mark
	stream.size_algorithm_ = size
	stream.pull_algorithm_ = pull
	stream.cancel_algorithm_ = cancel
	start() or {
		stream.error(err.msg())
		return err
	}
	stream.started_ = true
	stream.call_pull_if_needed()
}

pub fn set_up_readable_stream_default_controller_from_underlying_source(mut stream ReadableStream, source UnderlyingSource, high_water_mark f64, size SizeAlgorithm) ! {
	mut controller := ReadableStreamDefaultController{
		stream_: &stream
	}
	set_up_readable_stream_default_controller(mut stream, mut controller, source.start or { no_op_start_algorithm }, source.pull or { no_op_pull_algorithm }, source.cancel or { no_op_cancel_algorithm }, high_water_mark, size)!
}

fn no_op_start_algorithm() ! {}
fn no_op_pull_algorithm() ! {}
fn no_op_cancel_algorithm(_ Value) ! {}

pub fn readable_byte_stream_controller_call_pull_if_needed(mut controller ReadableByteStreamController) {
	controller.stream_.call_pull_if_needed()
}

pub fn readable_byte_stream_controller_clear_algorithms(mut controller ReadableByteStreamController) {
	controller.stream_.pull_algorithm_ = none
	controller.stream_.cancel_algorithm_ = none
}

pub fn readable_byte_stream_controller_clear_pending_pull_intos(mut controller ReadableByteStreamController) {
	controller.pending_pull_intos_.clear()
	controller.stream_.invalidate_byob_request()
}

pub fn readable_byte_stream_controller_close(mut controller ReadableByteStreamController) ! {
	controller.close()!
}

pub fn readable_byte_stream_controller_commit_pull_into_descriptor(mut stream ReadableStream, descriptor PullIntoDescriptor) {
	bytes := []u8{len: descriptor.bytes_filled}
	readable_stream_fulfill_read_into_request(mut stream, bytes, stream.state_ == .closed)
}

pub fn readable_byte_stream_controller_convert_pull_into_descriptor(descriptor PullIntoDescriptor) Value {
	return bytes_value([]u8{len: descriptor.bytes_filled})
}

pub fn readable_byte_stream_controller_enqueue(mut controller ReadableByteStreamController, chunk Value) ! {
	if chunk.kind != .bytes {
		return error('TypeError: byte controller requires a byte chunk')
	}
	controller.enqueue(chunk.bytes_)!
}

pub fn readable_byte_stream_controller_enqueue_chunk_to_queue(mut controller ReadableByteStreamController, buffer &ArrayBuffer, byte_offset int, byte_length int) ! {
	controller.enqueue(clone_as_uint8_array(buffer, byte_offset, byte_length)!)!
}

pub fn readable_byte_stream_controller_enqueue_cloned_chunk_to_queue(mut controller ReadableByteStreamController, buffer &ArrayBuffer, byte_offset int, byte_length int) ! {
	readable_byte_stream_controller_enqueue_chunk_to_queue(mut controller, buffer, byte_offset, byte_length)!
}

pub fn readable_byte_stream_controller_enqueue_detached_pull_into_to_queue(mut controller ReadableByteStreamController, descriptor PullIntoDescriptor) ! {
	controller.enqueue([]u8{len: descriptor.bytes_filled})!
}

pub fn readable_byte_stream_controller_error(mut controller ReadableByteStreamController, reason Value) {
	controller.error(reason.description())
}

pub fn readable_byte_stream_controller_fill_head_pull_into_descriptor(_ &ReadableByteStreamController, size int, mut descriptor PullIntoDescriptor) {
	descriptor.bytes_filled += size
	if descriptor.bytes_filled > descriptor.byte_length {
		descriptor.bytes_filled = descriptor.byte_length
	}
}

pub fn readable_byte_stream_controller_fill_pull_into_descriptor_from_queue(mut controller ReadableByteStreamController, mut descriptor PullIntoDescriptor) bool {
	remaining := descriptor.byte_length - descriptor.bytes_filled
	if remaining <= 0 {
		return true
	}
	bytes := controller.stream_.take_bytes_from_queue(remaining)
	descriptor.bytes_filled += bytes.len
	return descriptor.bytes_filled >= descriptor.minimum_fill
}

pub fn readable_byte_stream_controller_fill_read_request_from_queue(mut controller ReadableByteStreamController) {
	if controller.stream_.pending_reads_.len == 0 || controller.stream_.queue_.is_empty() {
		return
	}
	value := controller.stream_.queue_.dequeue_value() or {
		controller.stream_.error(err.msg())
		return
	}
	readable_stream_fulfill_read_request(mut controller.stream_, value, false)
}

pub fn readable_byte_stream_controller_get_byob_request(mut controller ReadableByteStreamController) ?&ReadableStreamBYOBRequest {
	return controller.byob_request()
}

pub fn readable_byte_stream_controller_get_desired_size(controller &ReadableByteStreamController) ?f64 {
	return controller.desired_size()
}

pub fn readable_byte_stream_controller_handle_queue_drain(mut controller ReadableByteStreamController) {
	if controller.stream_.queue_.is_empty() && controller.stream_.close_requested_ {
		controller.stream_.close_internal()
	} else {
		controller.stream_.call_pull_if_needed()
	}
}

pub fn readable_byte_stream_controller_invalidate_byob_request(mut controller ReadableByteStreamController) {
	controller.stream_.invalidate_byob_request()
}

pub fn readable_byte_stream_controller_process_pull_into_descriptors_using_queue(mut controller ReadableByteStreamController) {
	for controller.pending_pull_intos_.len > 0 {
		mut descriptor := controller.pending_pull_intos_[0]
		if !readable_byte_stream_controller_fill_pull_into_descriptor_from_queue(mut controller, mut descriptor) {
			controller.pending_pull_intos_[0] = descriptor
			return
		}
		controller.pending_pull_intos_.delete(0)
		readable_byte_stream_controller_commit_pull_into_descriptor(mut controller.stream_, descriptor)
	}
}

pub fn readable_byte_stream_controller_process_read_requests_using_queue(mut controller ReadableByteStreamController) {
	for controller.stream_.pending_reads_.len > 0 && !controller.stream_.queue_.is_empty() {
		readable_byte_stream_controller_fill_read_request_from_queue(mut controller)
	}
}

pub fn readable_byte_stream_controller_pull_into(mut controller ReadableByteStreamController, view_length int, minimum int) &BYOBReadPromise {
	if controller.stream_.reader_kind_ != .byob || isnil(controller.stream_.byob_reader_) {
		return BYOBReadPromise.rejected('TypeError: Stream has no BYOB reader')
	}
	mut reader := controller.stream_.byob_reader_
	return reader.read(view_length, minimum)
}

pub fn readable_byte_stream_controller_respond(mut controller ReadableByteStreamController, bytes_written u64) ! {
	mut active_request := controller.byob_request() or { return error('TypeError: No active BYOB request') }
	active_request.respond(bytes_written)!
}

pub fn readable_byte_stream_controller_respond_in_closed_state(mut controller ReadableByteStreamController, descriptor PullIntoDescriptor) {
	readable_byte_stream_controller_commit_pull_into_descriptor(mut controller.stream_, descriptor)
}

pub fn readable_byte_stream_controller_respond_in_readable_state(mut controller ReadableByteStreamController, bytes_written u64, mut descriptor PullIntoDescriptor) ! {
	descriptor.bytes_filled += int(bytes_written)
	if descriptor.bytes_filled > descriptor.byte_length {
		return error('RangeError: bytesWritten exceeds the pull-into descriptor')
	}
	if descriptor.bytes_filled >= descriptor.minimum_fill {
		readable_byte_stream_controller_commit_pull_into_descriptor(mut controller.stream_, descriptor)
	}
}

pub fn readable_byte_stream_controller_respond_internal(mut controller ReadableByteStreamController, bytes_written u64) ! {
	readable_byte_stream_controller_respond(mut controller, bytes_written)!
}

pub fn readable_byte_stream_controller_respond_with_new_view(mut controller ReadableByteStreamController, view []u8) ! {
	mut active_request := controller.byob_request() or { return error('TypeError: No active BYOB request') }
	active_request.respond_with_new_view(view)!
}

pub fn readable_byte_stream_controller_shift_pending_pull_into(mut controller ReadableByteStreamController) !PullIntoDescriptor {
	if controller.pending_pull_intos_.len == 0 {
		return error('InternalError: No pending pull-into descriptor')
	}
	descriptor := controller.pending_pull_intos_[0]
	controller.pending_pull_intos_.delete(0)
	return descriptor
}

pub fn readable_byte_stream_controller_should_call_pull(controller &ReadableByteStreamController) bool {
	stream := controller.stream_
	if !stream.started_ || stream.state_ != .readable || stream.close_requested_ {
		return false
	}
	desired := stream.desired_size() or { return false }
	return desired > 0 || stream.pending_reads_.len > 0 || !isnil(stream.pending_byob_)
}

pub fn set_up_readable_byte_stream_controller(mut stream ReadableStream, mut controller ReadableByteStreamController, start StartAlgorithm, pull PullAlgorithm, cancel CancelAlgorithm, high_water_mark f64, auto_allocate_chunk_size ?u64) ! {
	if high_water_mark < 0 {
		return error('RangeError: highWaterMark must be non-negative')
	}
	if size := auto_allocate_chunk_size {
		if size == 0 {
			return error('TypeError: autoAllocateChunkSize must be positive')
		}
	}
	controller.stream_ = &stream
	stream.byte_controller_ = &controller
	stream.default_controller_ = unsafe { nil }
	stream.byte_stream_ = true
	stream.high_water_mark_ = high_water_mark
	stream.auto_allocate_size_ = auto_allocate_chunk_size
	stream.pull_algorithm_ = pull
	stream.cancel_algorithm_ = cancel
	start() or {
		stream.error(err.msg())
		return err
	}
	stream.started_ = true
	stream.call_pull_if_needed()
}

pub fn set_up_readable_byte_stream_controller_from_underlying_source(mut stream ReadableStream, source UnderlyingSource, high_water_mark f64) ! {
	mut controller := ReadableByteStreamController{
		stream_: &stream
	}
	set_up_readable_byte_stream_controller(mut stream, mut controller, source.start or { no_op_start_algorithm }, source.pull or { no_op_pull_algorithm }, source.cancel or { no_op_cancel_algorithm }, high_water_mark, source.auto_allocate_chunk_size)!
}
