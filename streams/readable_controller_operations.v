// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Direct translations of the controller entry points from
// ReadableStreamOperations. Controller slots live on ReadableStream in the V
// representation, so the accessors below project and mutate that canonical
// state.
module streams

pub fn (mut controller ReadableStreamDefaultController) cancel_steps(reason Value) &VoidPromise {
	mut stream := controller.stream_
	stream.queue_.reset()
	mut result := VoidPromise.fulfilled_in(stream.realm_)
	if algorithm := stream.cancel_algorithm_ {
		algorithm(reason) or { result = VoidPromise.rejected_in(stream.realm_, err.msg()) }
	}
	readable_stream_default_controller_clear_algorithms(mut controller)
	return result
}

pub fn (mut controller ReadableStreamDefaultController) pull_steps() &ReadPromise {
	return controller.pull_steps_in(controller.stream_.realm_)
}

fn (mut controller ReadableStreamDefaultController) pull_steps_in(promise_realm StreamRealm) &ReadPromise {
	mut stream := controller.stream_
	if !stream.queue_.is_empty() {
		value := stream.queue_.dequeue_value() or { return ReadPromise.rejected_in(promise_realm, stream.result_realm_, err.msg()) }
		if stream.close_requested_ && stream.queue_.is_empty() {
			readable_stream_default_controller_clear_algorithms(mut controller)
			stream.close_internal()
		} else {
			readable_stream_default_controller_call_pull_if_needed(mut controller)
		}
		return ReadPromise.fulfilled_in(promise_realm, stream.result_realm_, value, false)
	}
	promise := ReadPromise.pending_in(promise_realm, stream.result_realm_)
	readable_stream_add_read_request(mut stream, promise)
	readable_stream_default_controller_call_pull_if_needed(mut controller)
	return promise
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
	return controller.stream_.queue_.queue_.values()
}

pub fn (controller &ReadableStreamDefaultController) queue_total_size() f64 {
	return controller.stream_.queue_.total_size_
}

pub fn (mut controller ReadableStreamDefaultController) set_queue_total_size(value f64) {
	controller.stream_.queue_.total_size_ = value
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
	readable_byte_stream_controller_clear_pending_pull_intos(mut controller)
	controller.reset_byte_queue()
	mut result := VoidPromise.fulfilled_in(stream.realm_)
	if algorithm := stream.cancel_algorithm_ {
		algorithm(reason) or { result = VoidPromise.rejected_in(stream.realm_, err.msg()) }
	}
	readable_byte_stream_controller_clear_algorithms(mut controller)
	return result
}

pub fn (mut controller ReadableByteStreamController) pull_steps() &ReadPromise {
	return controller.pull_steps_in(controller.stream_.realm_)
}

fn (mut controller ReadableByteStreamController) pull_steps_in(promise_realm StreamRealm) &ReadPromise {
	mut stream := controller.stream_
	return stream.byte_controller_pull_steps_in(promise_realm)
}

pub fn (mut controller ReadableByteStreamController) release_steps() {
	if controller.pending_pull_intos_.len > 0 {
		mut first := controller.pending_pull_intos_.first() or { return }
		first.reader_type = .none
		controller.pending_pull_intos_.clear()
		controller.pending_pull_intos_.append(first)
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
	return controller.pending_pull_intos_.values()
}

pub fn (controller &ReadableByteStreamController) queue() []ReadableByteStreamQueueEntry {
	return controller.byte_queue_entries()
}

pub fn (controller &ReadableByteStreamController) queue_total_size() f64 {
	return controller.queue_total_size_
}

pub fn (mut controller ReadableByteStreamController) set_queue_total_size(value f64) {
	controller.queue_total_size_ = value
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
	if !readable_stream_default_controller_can_close_or_enqueue(controller) {
		return
	}
	mut stream := controller.stream_
	stream.close_requested_ = true
	if stream.queue_.is_empty() {
		readable_stream_default_controller_clear_algorithms(mut controller)
		stream.close_internal()
	}
	pump_readable_tee_source(mut stream)
	pump_readable_pipe(mut stream)
}

pub fn readable_stream_default_controller_enqueue(mut controller ReadableStreamDefaultController, chunk Value) ! {
	// ReadableStreamDefaultControllerEnqueue is the internal abstract operation:
	// unlike the public IDL method it returns normally when close/enqueue is no
	// longer allowed.
	if !readable_stream_default_controller_can_close_or_enqueue(controller) {
		return
	}
	mut stream := controller.stream_
	if stream.locked() && readable_stream_get_num_read_requests(stream) > 0 {
		readable_stream_fulfill_read_request(mut stream, chunk, false)
	} else {
		chunk_size := stream.size_algorithm_(chunk) or {
			readable_stream_default_controller_error(mut controller, string_value(err.msg()))
			return err
		}
		stream.queue_.enqueue_value_with_size(chunk, chunk_size) or {
			readable_stream_default_controller_error(mut controller, string_value(err.msg()))
			return err
		}
	}
	readable_stream_default_controller_call_pull_if_needed(mut controller)
	pump_readable_tee_source(mut stream)
	pump_readable_pipe(mut stream)
}

pub fn readable_stream_default_controller_error(mut controller ReadableStreamDefaultController, reason Value) {
	mut stream := controller.stream_
	if stream.state_ != .readable {
		return
	}
	stream.queue_.reset()
	readable_stream_default_controller_clear_algorithms(mut controller)
	stream.error_internal(reason.description())
}

pub fn readable_stream_default_controller_get_desired_size(controller &ReadableStreamDefaultController) ?f64 {
	return controller.desired_size()
}

pub fn readable_stream_default_controller_has_backpressure(controller &ReadableStreamDefaultController) bool {
	return !readable_stream_default_controller_should_call_pull(controller)
}

pub fn readable_stream_default_controller_can_close_or_enqueue(controller &ReadableStreamDefaultController) bool {
	return controller.stream_.state_ == .readable && !controller.stream_.close_requested_
}

pub fn set_up_readable_stream_default_controller(mut stream ReadableStream, mut controller ReadableStreamDefaultController, start StartAlgorithm, pull PullAlgorithm, cancel CancelAlgorithm, high_water_mark f64, size SizeAlgorithm) ! {
	if high_water_mark < 0 {
		return error('RangeError: highWaterMark must be non-negative')
	}
	controller.stream_ = &stream
	stream.queue_.reset()
	stream.started_ = false
	stream.close_requested_ = false
	stream.pull_again_ = false
	stream.pulling_ = false
	stream.default_controller_ = &controller
	stream.byte_controller_ = unsafe { nil }
	stream.byte_stream_ = false
	stream.high_water_mark_ = high_water_mark
	stream.size_algorithm_ = size
	stream.pull_algorithm_ = pull
	stream.cancel_algorithm_ = cancel
	start()!
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
	controller.stream_.invalidate_byob_request()
	controller.pending_pull_intos_.clear()
}

pub fn readable_byte_stream_controller_close(mut controller ReadableByteStreamController) ! {
	mut stream := controller.stream_
	if stream.close_requested_ || stream.state_ != .readable {
		return
	}
	if controller.queue_total_size_ > 0 {
		stream.close_requested_ = true
		return
	}
	if controller.pending_pull_intos_.len > 0 {
		first := controller.pending_pull_intos_.first()!
		if first.bytes_filled % first.element_size != 0 {
			reason := 'TypeError: Cannot close controller in the middle of processing a write request'
			readable_byte_stream_controller_error(mut controller, string_value(reason))
			return error(reason)
		}
	}
	readable_byte_stream_controller_clear_algorithms(mut controller)
	stream.close_internal()
	pump_readable_tee_source(mut stream)
	pump_readable_pipe(mut stream)
}

pub fn readable_byte_stream_controller_commit_pull_into_descriptor(mut stream ReadableStream, descriptor PullIntoDescriptor) {
	if descriptor.reader_type == .none || descriptor.element_size <= 0 || descriptor.bytes_filled % descriptor.element_size != 0 {
		return
	}
	bytes := pull_into_descriptor_bytes(&descriptor)
	done := stream.state_ == .closed
	if descriptor.reader_type == .default_reader {
		readable_stream_fulfill_read_request(mut stream, bytes_value(bytes), done)
	} else {
		readable_stream_fulfill_read_into_request(mut stream, bytes, done)
	}
}

pub fn readable_byte_stream_controller_convert_pull_into_descriptor(descriptor PullIntoDescriptor) Value {
	if descriptor.element_size <= 0 || descriptor.bytes_filled > descriptor.byte_length || descriptor.bytes_filled % descriptor.element_size != 0 {
		return undefined_value()
	}
	return bytes_value(pull_into_descriptor_bytes(&descriptor))
}

pub fn readable_byte_stream_controller_enqueue(mut controller ReadableByteStreamController, chunk Value) ! {
	if chunk.kind != .bytes {
		return error('TypeError: byte controller requires a byte chunk')
	}
	mut stream := controller.stream_
	if stream.close_requested_ || stream.state_ != .readable {
		return
	}
	// TransferArrayBuffer moves the backing store. Value cannot expose a detached
	// input slice, so retain its backing store here instead of copying it.
	mut transferred_buffer := ArrayBuffer{
		data_: chunk.bytes_
	}
	if controller.pending_pull_intos_.len > 0 {
		stream.invalidate_byob_request()
		mut first := controller.pending_pull_intos_.first()!
		transferred_descriptor_buffer := transfer_array_buffer(mut first.buffer)!
		first.buffer = transferred_descriptor_buffer
		controller.pending_pull_intos_.set_first(first)!
		if first.reader_type == .none {
			readable_byte_stream_controller_enqueue_detached_pull_into_to_queue(mut controller, first)!
		}
	}

	if readable_stream_has_default_reader(stream) {
		readable_byte_stream_controller_process_read_requests_using_queue(mut controller)
		if readable_stream_get_num_read_requests(stream) == 0 {
			readable_byte_stream_controller_enqueue_chunk_to_queue(mut controller, &transferred_buffer, 0, transferred_buffer.byte_length())!
		} else {
			if controller.pending_pull_intos_.len > 0 {
				_ = readable_byte_stream_controller_shift_pending_pull_into(mut controller)!
			}
			readable_stream_fulfill_read_request(mut stream, bytes_value(chunk.bytes_), false)
		}
	} else if readable_stream_has_byob_reader(stream) {
		readable_byte_stream_controller_enqueue_chunk_to_queue(mut controller, &transferred_buffer, 0, transferred_buffer.byte_length())!
		filled := readable_byte_stream_controller_process_pull_into_descriptors_using_queue(mut controller)
		for descriptor in filled {
			readable_byte_stream_controller_commit_pull_into_descriptor(mut stream, descriptor)
		}
	} else {
		readable_byte_stream_controller_enqueue_chunk_to_queue(mut controller, &transferred_buffer, 0, transferred_buffer.byte_length())!
	}
	readable_byte_stream_controller_call_pull_if_needed(mut controller)
	pump_readable_tee_source(mut stream)
	pump_readable_pipe(mut stream)
}

pub fn readable_byte_stream_controller_enqueue_chunk_to_queue(mut controller ReadableByteStreamController, buffer &ArrayBuffer, byte_offset int, byte_length int) ! {
	if buffer.detached_ || byte_offset < 0 || byte_length < 0 || byte_offset > buffer.data_.len || byte_length > buffer.data_.len - byte_offset {
		return error('RangeError: ArrayBuffer view is out of bounds')
	}
	controller.append_byte_queue_entry(buffer, byte_offset, byte_length)
}

pub fn readable_byte_stream_controller_enqueue_cloned_chunk_to_queue(mut controller ReadableByteStreamController, buffer &ArrayBuffer, byte_offset int, byte_length int) ! {
	bytes := clone_as_uint8_array(buffer, byte_offset, byte_length) or {
		readable_byte_stream_controller_error(mut controller, string_value(err.msg()))
		return err
	}
	cloned := ArrayBuffer.from_bytes(bytes)
	readable_byte_stream_controller_enqueue_chunk_to_queue(mut controller, &cloned, 0, byte_length)!
}

pub fn readable_byte_stream_controller_enqueue_detached_pull_into_to_queue(mut controller ReadableByteStreamController, descriptor PullIntoDescriptor) ! {
	if descriptor.reader_type != .none {
		return error('InternalError: Pull-into descriptor still has a reader')
	}
	if descriptor.bytes_filled > 0 {
		readable_byte_stream_controller_enqueue_cloned_chunk_to_queue(mut controller, &descriptor.buffer, descriptor.byte_offset, descriptor.bytes_filled)!
	}
	_ = readable_byte_stream_controller_shift_pending_pull_into(mut controller)!
}

pub fn readable_byte_stream_controller_error(mut controller ReadableByteStreamController, reason Value) {
	mut stream := controller.stream_
	if stream.state_ != .readable {
		return
	}
	readable_byte_stream_controller_clear_pending_pull_intos(mut controller)
	controller.reset_byte_queue()
	readable_byte_stream_controller_clear_algorithms(mut controller)
	stream.error_internal(reason.description())
}

pub fn readable_byte_stream_controller_fill_head_pull_into_descriptor(_ &ReadableByteStreamController, size int, mut descriptor PullIntoDescriptor) {
	descriptor.bytes_filled += size
}

pub fn readable_byte_stream_controller_fill_pull_into_descriptor_from_queue(mut controller ReadableByteStreamController, mut descriptor PullIntoDescriptor) bool {
	remaining_capacity := descriptor.byte_length - descriptor.bytes_filled
	available := int(controller.queue_total_size_)
	max_bytes_to_copy := if available < remaining_capacity { available } else { remaining_capacity }
	max_bytes_filled := descriptor.bytes_filled + max_bytes_to_copy
	remainder_bytes := max_bytes_filled % descriptor.element_size
	max_aligned_bytes := max_bytes_filled - remainder_bytes
	mut total_bytes_to_copy_remaining := max_bytes_to_copy
	mut ready := false
	if max_aligned_bytes >= descriptor.minimum_fill {
		total_bytes_to_copy_remaining = max_aligned_bytes - descriptor.bytes_filled
		ready = true
	}
	for total_bytes_to_copy_remaining > 0 {
		mut entry := controller.queue_head_
		if isnil(entry) {
			return false
		}
		bytes_to_copy := if total_bytes_to_copy_remaining < entry.byte_length {
			total_bytes_to_copy_remaining
		} else {
			entry.byte_length
		}
		source_start := entry.byte_offset
		source := unsafe { entry.buffer.data_[source_start..source_start + bytes_to_copy] }
		copy_into_pull_into_descriptor(mut descriptor, source, bytes_to_copy) or {
			return false
		}
		if bytes_to_copy == entry.byte_length {
			_ = controller.take_first_byte_queue_entry() or { return false }
		} else {
			entry.byte_offset += bytes_to_copy
			entry.byte_length -= bytes_to_copy
			controller.queue_total_size_ -= f64(bytes_to_copy)
		}
		readable_byte_stream_controller_fill_head_pull_into_descriptor(&controller, bytes_to_copy, mut descriptor)
		total_bytes_to_copy_remaining -= bytes_to_copy
	}
	return ready
}

pub fn readable_byte_stream_controller_fill_read_request_from_queue(mut controller ReadableByteStreamController) {
	if controller.stream_.pending_reads_.len == 0 || controller.queue_total_size_ <= 0 {
		return
	}
	// ProcessReadRequestsUsingQueue removes the request before queue drain. This
	// ordering matters when the dequeued chunk is the final chunk of a
	// close-requested stream: closing must not resolve this request as `done`
	// before its chunk steps run.
	mut request := controller.stream_.pending_reads_.shift() or { return }
	entry := controller.take_first_byte_queue_entry() or {
		request.reject(err.msg())
		readable_byte_stream_controller_error(mut controller, string_value(err.msg()))
		return
	}
	value := bytes_value(unsafe {
		entry.buffer.data_[entry.byte_offset..entry.byte_offset + entry.byte_length]
	})
	readable_byte_stream_controller_handle_queue_drain(mut controller)
	request.resolve(value, false)
}

pub fn readable_byte_stream_controller_get_byob_request(mut controller ReadableByteStreamController) ?&ReadableStreamBYOBRequest {
	mut stream := controller.stream_
	if isnil(stream.byob_request_) && controller.pending_pull_intos_.len > 0 {
		descriptor := controller.pending_pull_intos_.first() or { return none }
		start := descriptor.byte_offset + descriptor.bytes_filled
		length := descriptor.byte_length - descriptor.bytes_filled
		view := unsafe { descriptor.buffer.data_[start..start + length] }
		stream.byob_request_ = &ReadableStreamBYOBRequest{
			controller_: &controller
			view_: view
			active_: true
		}
	}
	if isnil(stream.byob_request_) {
		return none
	}
	return stream.byob_request_
}

pub fn readable_byte_stream_controller_get_desired_size(controller &ReadableByteStreamController) ?f64 {
	return match controller.stream_.state_ {
		.errored { none }
		.closed { 0.0 }
		.readable { controller.stream_.high_water_mark_ - controller.queue_total_size_ }
	}
}

pub fn readable_byte_stream_controller_handle_queue_drain(mut controller ReadableByteStreamController) {
	if controller.queue_total_size_ == 0 && controller.stream_.close_requested_ {
		readable_byte_stream_controller_clear_algorithms(mut controller)
		controller.stream_.close_internal()
	} else {
		readable_byte_stream_controller_call_pull_if_needed(mut controller)
	}
}

pub fn readable_byte_stream_controller_invalidate_byob_request(mut controller ReadableByteStreamController) {
	controller.stream_.invalidate_byob_request()
}

pub fn readable_byte_stream_controller_process_pull_into_descriptors_using_queue(mut controller ReadableByteStreamController) []PullIntoDescriptor {
	mut filled := []PullIntoDescriptor{}
	for controller.pending_pull_intos_.len > 0 {
		if controller.queue_total_size_ == 0 {
			break
		}
		mut descriptor := controller.pending_pull_intos_.first() or { break }
		if readable_byte_stream_controller_fill_pull_into_descriptor_from_queue(mut controller, mut descriptor) {
			_ = readable_byte_stream_controller_shift_pending_pull_into(mut controller) or { break }
			filled << descriptor
		} else {
			controller.pending_pull_intos_.set_first(descriptor) or { break }
			break
		}
	}
	return filled
}

pub fn readable_byte_stream_controller_process_read_requests_using_queue(mut controller ReadableByteStreamController) {
	for controller.stream_.pending_reads_.len > 0 {
		if controller.queue_total_size_ == 0 {
			return
		}
		readable_byte_stream_controller_fill_read_request_from_queue(mut controller)
	}
}

pub fn readable_byte_stream_controller_pull_into(mut controller ReadableByteStreamController, view_length int, minimum int) &BYOBReadPromise {
	if controller.stream_.reader_kind_ != .byob || isnil(controller.stream_.byob_reader_) {
		return BYOBReadPromise.rejected('TypeError: Stream has no BYOB reader')
	}
	mut promise := BYOBReadPromise.pending()
	readable_byte_stream_controller_pull_into_request(mut controller, view_length, minimum, mut promise)
	return promise
}

pub fn readable_byte_stream_controller_respond(mut controller ReadableByteStreamController, bytes_written u64) ! {
	if controller.pending_pull_intos_.len == 0 {
		return error('InternalError: No pending pull-into descriptor')
	}
	mut descriptor := controller.pending_pull_intos_.first()!
	state := controller.stream_.state_
	if state == .closed {
		if bytes_written != 0 {
			return error('TypeError: Bytes written is not zero for closed stream')
		}
	} else {
		if state != .readable {
			return error('TypeError: Stream is not readable')
		}
		if bytes_written == 0 {
			return error('TypeError: Bytes written is zero for stream which is not closed')
		}
		if descriptor.bytes_filled + int(bytes_written) > descriptor.byte_length {
			return error('RangeError: Bytes written is greater than the pull requests byte length')
		}
	}
	// The BYOB request's view aliases this descriptor's buffer, as the JS
	// ArrayBufferView does upstream. Writes are already present in the buffer.
	transferred := transfer_array_buffer(mut descriptor.buffer)!
	descriptor.buffer = transferred
	controller.pending_pull_intos_.set_first(descriptor)!
	readable_byte_stream_controller_respond_internal(mut controller, bytes_written)!
}

pub fn readable_byte_stream_controller_respond_in_closed_state(mut controller ReadableByteStreamController, descriptor PullIntoDescriptor) {
	if descriptor.bytes_filled % descriptor.element_size != 0 {
		return
	}
	if descriptor.reader_type == .none {
		_ = readable_byte_stream_controller_shift_pending_pull_into(mut controller) or { return }
	}
	mut stream := controller.stream_
	if readable_stream_has_byob_reader(stream) {
		mut filled := []PullIntoDescriptor{}
		for filled.len < readable_stream_get_num_read_into_requests(stream) && controller.pending_pull_intos_.len > 0 {
			filled << readable_byte_stream_controller_shift_pending_pull_into(mut controller) or {
				break
			}
		}
		for pull_into in filled {
			readable_byte_stream_controller_commit_pull_into_descriptor(mut stream, pull_into)
		}
	}
}

pub fn readable_byte_stream_controller_respond_in_readable_state(mut controller ReadableByteStreamController, bytes_written u64, mut descriptor PullIntoDescriptor) ! {
	readable_byte_stream_controller_fill_head_pull_into_descriptor(&controller, int(bytes_written), mut descriptor)
	if descriptor.reader_type == .none {
		controller.pending_pull_intos_.set_first(descriptor)!
		readable_byte_stream_controller_enqueue_detached_pull_into_to_queue(mut controller, descriptor)!
		filled := readable_byte_stream_controller_process_pull_into_descriptors_using_queue(mut controller)
		mut stream := controller.stream_
		for pull_into in filled {
			readable_byte_stream_controller_commit_pull_into_descriptor(mut stream, pull_into)
		}
		return
	}
	if descriptor.bytes_filled < descriptor.minimum_fill {
		controller.pending_pull_intos_.set_first(descriptor)!
		return
	}
	_ = readable_byte_stream_controller_shift_pending_pull_into(mut controller)!
	remainder_size := descriptor.bytes_filled % descriptor.element_size
	if remainder_size > 0 {
		end := descriptor.byte_offset + descriptor.bytes_filled
		readable_byte_stream_controller_enqueue_cloned_chunk_to_queue(mut controller, &descriptor.buffer, end - remainder_size, remainder_size)!
	}
	descriptor.bytes_filled -= remainder_size
	filled := readable_byte_stream_controller_process_pull_into_descriptors_using_queue(mut controller)
	mut stream := controller.stream_
	readable_byte_stream_controller_commit_pull_into_descriptor(mut stream, descriptor)
	for pull_into in filled {
		readable_byte_stream_controller_commit_pull_into_descriptor(mut stream, pull_into)
	}
}

pub fn readable_byte_stream_controller_respond_internal(mut controller ReadableByteStreamController, bytes_written u64) ! {
	if controller.pending_pull_intos_.len == 0 {
		return error('InternalError: No pending pull-into descriptor')
	}
	mut descriptor := controller.pending_pull_intos_.first()!
	controller.stream_.invalidate_byob_request()
	if controller.stream_.state_ == .closed {
		readable_byte_stream_controller_respond_in_closed_state(mut controller, descriptor)
	} else {
		readable_byte_stream_controller_respond_in_readable_state(mut controller, bytes_written, mut descriptor)!
	}
	readable_byte_stream_controller_call_pull_if_needed(mut controller)
	mut stream := controller.stream_
	pump_readable_tee_source(mut stream)
	pump_readable_pipe(mut stream)
}

pub fn readable_byte_stream_controller_respond_with_new_view(mut controller ReadableByteStreamController, view []u8) ! {
	if controller.pending_pull_intos_.len == 0 {
		return error('InternalError: No pending pull-into descriptor')
	}
	descriptor := controller.pending_pull_intos_.first()!
	if controller.stream_.state_ == .closed {
		if view.len != 0 {
			return error('TypeError: Byte length is not zero for closed stream')
		}
	} else if view.len == 0 {
		return error('TypeError: Byte length is zero for stream which is not closed')
	}
	if descriptor.bytes_filled + view.len > descriptor.byte_length {
		return error('RangeError: Byte length is greater than the pull request byte length')
	}
	if isnil(controller.stream_.byob_request_) {
		return error('TypeError: No active BYOB request')
	}
	mut request := controller.stream_.byob_request_
	copy(mut request.view_[..view.len], view)
	request.written_length_ = view.len
	readable_byte_stream_controller_respond(mut controller, u64(view.len))!
}

pub fn readable_byte_stream_controller_shift_pending_pull_into(mut controller ReadableByteStreamController) !PullIntoDescriptor {
	return controller.pending_pull_intos_.shift()
}

pub fn readable_byte_stream_controller_should_call_pull(controller &ReadableByteStreamController) bool {
	stream := controller.stream_
	if !stream.started_ || stream.state_ != .readable || stream.close_requested_ {
		return false
	}
	if readable_stream_has_default_reader(stream) && readable_stream_get_num_read_requests(stream) > 0 {
		return true
	}
	if readable_stream_has_byob_reader(stream) && readable_stream_get_num_read_into_requests(stream) > 0 {
		return true
	}
	desired := stream.desired_size() or { return false }
	return desired > 0
}

pub fn set_up_readable_byte_stream_controller(mut stream ReadableStream, mut controller ReadableByteStreamController, start StartAlgorithm, pull PullAlgorithm, cancel CancelAlgorithm, high_water_mark f64, auto_allocate_chunk_size ?u64) ! {
	if high_water_mark < 0 {
		return error('RangeError: highWaterMark must be non-negative')
	}
	if size := auto_allocate_chunk_size {
		if size == 0 {
			return error('TypeError: Cannot use an auto allocate chunk size of 0')
		}
	}
	controller.stream_ = &stream
	stream.byte_controller_ = &controller
	stream.default_controller_ = unsafe { nil }
	stream.byte_stream_ = true
	stream.high_water_mark_ = high_water_mark
	stream.pull_again_ = false
	stream.pulling_ = false
	stream.close_requested_ = false
	stream.started_ = false
	stream.queue_.reset()
	controller.reset_byte_queue()
	stream.invalidate_byob_request()
	controller.pending_pull_intos_.clear()
	stream.auto_allocate_size_ = auto_allocate_chunk_size
	stream.pull_algorithm_ = pull
	stream.cancel_algorithm_ = cancel
	start()!
	stream.started_ = true
	readable_byte_stream_controller_call_pull_if_needed(mut controller)
}

pub fn set_up_readable_byte_stream_controller_from_underlying_source(mut stream ReadableStream, source UnderlyingSource, high_water_mark f64) ! {
	mut controller := ReadableByteStreamController{
		stream_: &stream
	}
	set_up_readable_byte_stream_controller(mut stream, mut controller, source.start or { no_op_start_algorithm }, source.pull or { no_op_pull_algorithm }, source.cancel or { no_op_cancel_algorithm }, high_water_mark, source.auto_allocate_chunk_size)!
}
