// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ReadableStreamPipeTo, ReadableStreamTee, and transferable
// streams from AbstractOperations, ReadableStream, and WritableStream.
module streams

pub struct StreamPipeOptions {
pub:
	prevent_close  bool
	prevent_abort  bool
	prevent_cancel bool
	signal         ?&AbortSignal
}

pub struct ReadableWritablePair {
pub:
	readable &ReadableStream
	writable &WritableStream
}

pub struct ReadableStreamPair {
pub:
	first  &ReadableStream
	second &ReadableStream
}

fn unlock_pipe(mut source ReadableStream, mut destination WritableStream) {
	if !isnil(source.pipe_read_request_) {
		mut request := source.pipe_read_request_
		if request.state() == .pending {
			source.pending_reads_.remove(request)
			request.reject('TypeError: Pipe reader has been released')
		}
		source.pipe_read_request_ = unsafe { nil }
	}
	if mut signal := source.pipe_options_.signal {
		for index, pipe_source in signal.pipes_ {
			if pipe_source == &source {
				signal.pipes_.delete(index)
				break
			}
		}
	}
	if !isnil(source.default_reader_) {
		mut reader := source.default_reader_
		reader.release_lock() or {}
	} else if source.reader_kind_ == .pipe {
		source.reader_kind_ = .none
	}
	if !isnil(destination.writer_) {
		mut writer := destination.writer_
		writer.release_lock()
	}
	source.pipe_destination_ = unsafe { nil }
	destination.pipe_source_ = unsafe { nil }
}

fn pipe_result_error(result &VoidPromise, original string) string {
	return if result.state() == .rejected { result.reason() } else { original }
}

fn abort_pipe(mut source ReadableStream, mut destination WritableStream, reason Value) string {
	mut final_reason := reason.description()
	if !source.pipe_options_.prevent_abort && destination.state_ == .writable {
		abort_result := destination.abort_internal(reason)
		final_reason = pipe_result_error(abort_result, final_reason)
	}
	if !source.pipe_options_.prevent_cancel && source.state_ == .readable {
		cancel_result := source.cancel_internal(reason)
		if cancel_result.state() == .rejected {
			final_reason = cancel_result.reason()
		}
	}
	return final_reason
}

fn fail_pipe(mut source ReadableStream, reason string) {
	if isnil(source.pipe_promise_) || source.pipe_promise_.state() != .pending {
		return
	}
	mut promise := source.pipe_promise_
	promise.reject(reason)
	mut destination := source.pipe_destination_
	unlock_pipe(mut source, mut destination)
}

fn finish_pipe(mut source ReadableStream) {
	if isnil(source.pipe_promise_) || source.pipe_promise_.state() != .pending {
		return
	}
	mut promise := source.pipe_promise_
	promise.resolve()
	mut destination := source.pipe_destination_
	unlock_pipe(mut source, mut destination)
}

fn pump_readable_pipe(mut source ReadableStream) {
	if isnil(source.pipe_destination_) || isnil(source.pipe_promise_) || source.pipe_promise_.state() != .pending || source.pipe_pumping_ {
		return
	}
	source.pipe_pumping_ = true
	defer {
		source.pipe_pumping_ = false
	}
	mut destination := source.pipe_destination_
	if signal := source.pipe_options_.signal {
		if signal.aborted() {
			reason := signal.reason()
			final_reason := abort_pipe(mut source, mut destination, reason)
			fail_pipe(mut source, final_reason)
			return
		}
	}
	if source.state_ == .errored {
		mut reason := source.stored_error_
		if !source.pipe_options_.prevent_abort && destination.state_ == .writable {
			result := destination.abort_internal(string_value(reason))
			reason = pipe_result_error(result, reason)
		}
		fail_pipe(mut source, reason)
		return
	}
	if destination.state_ == .errored || destination.state_ == .erroring {
		mut reason := destination.stored_error_
		if !source.pipe_options_.prevent_cancel {
			result := source.cancel_internal(string_value(reason))
			reason = pipe_result_error(result, reason)
		}
		fail_pipe(mut source, reason)
		return
	}
	if writable_stream_close_queued_or_in_flight(destination) || destination.state_ == .closed {
		destination_closed := 'TypeError: Destination stream was closed during piping operation'
		mut reason := destination_closed
		if !source.pipe_options_.prevent_cancel && source.state_ == .readable {
			result := source.cancel_internal(string_value(destination_closed))
			reason = pipe_result_error(result, reason)
		}
		fail_pipe(mut source, reason)
		return
	}
	for {
		if !isnil(source.pipe_read_request_) {
			request := source.pipe_read_request_
			if request.state() == .pending {
				return
			}
			source.pipe_read_request_ = unsafe { nil }
			if request.state() == .rejected {
				mut reason := request.reason()
				if !source.pipe_options_.prevent_abort && destination.state_ == .writable {
					result := destination.abort_internal(string_value(reason))
					reason = pipe_result_error(result, reason)
				}
				fail_pipe(mut source, reason)
				return
			}
			read_result := request.result()
			if read_result.done {
				if !source.pipe_options_.prevent_close {
					closed := destination.close_internal()
					if closed.state() == .rejected {
						fail_pipe(mut source, closed.reason())
						return
					}
				}
				finish_pipe(mut source)
				return
			}
			write := destination.write_internal(read_result.value)
			if write.state() == .rejected {
				mut reason := write.reason()
				if !source.pipe_options_.prevent_cancel && source.state_ == .readable {
					result := source.cancel_internal(string_value(reason))
					reason = pipe_result_error(result, reason)
				}
				fail_pipe(mut source, reason)
				return
			}
			continue
		}
		if source.state_ == .closed {
			if !source.pipe_options_.prevent_close {
				closed := destination.close_internal()
				if closed.state() == .rejected {
					fail_pipe(mut source, closed.reason())
					return
				}
			}
			finish_pipe(mut source)
			return
		}
		if !isnil(destination.writer_) {
			ready := destination.writer_.ready()
			if ready.state() == .pending {
				return
			}
			if ready.state() == .rejected {
				mut reason := ready.reason()
				if !source.pipe_options_.prevent_cancel && source.state_ == .readable {
					result := source.cancel_internal(string_value(reason))
					reason = pipe_result_error(result, reason)
				}
				fail_pipe(mut source, reason)
				return
			}
		}
		source.pipe_read_request_ = source.read_internal()
		if source.pipe_read_request_.state() == .pending {
			return
		}
	}
}

pub fn (mut source ReadableStream) pipe_to(mut destination WritableStream, options StreamPipeOptions) &VoidPromise {
	if source.locked() {
		return VoidPromise.rejected_in(source.realm_, 'TypeError: Source ReadableStream is locked')
	}
	if destination.locked() {
		return VoidPromise.rejected_in(source.realm_, 'TypeError: Destination WritableStream is locked')
	}
	if voidptr(&source) == voidptr(&destination) {
		return VoidPromise.rejected_in(source.realm_, 'TypeError: A stream cannot be piped to itself')
	}
	mut reader := ReadableStreamDefaultReader.create(source.realm_, mut source) or {
		return VoidPromise.rejected_in(source.realm_, err.msg())
	}
	writer := WritableStreamDefaultWriter.create(source.realm_, mut destination) or {
		reader.release_lock() or {}
		return VoidPromise.rejected_in(source.realm_, err.msg())
	}
	_ = writer
	source.disturbed_ = true
	source.pipe_destination_ = &destination
	destination.pipe_source_ = &source
	source.pipe_options_ = options
	source.pipe_promise_ = VoidPromise.pending_in(source.realm_)
	if mut signal := options.signal {
		signal.pipes_ << &source
	}
	pump_readable_pipe(mut source)
	return source.pipe_promise_
}

pub fn (mut source ReadableStream) pipe_through(pair ReadableWritablePair, options StreamPipeOptions) !&ReadableStream {
	if pair.readable.locked() {
		return error('TypeError: Transform readable side is locked')
	}
	mut writable := pair.writable
	promise := source.pipe_to(mut writable, options)
	if promise.state() == .rejected {
		return error(promise.reason())
	}
	return pair.readable
}

fn settle_tee_cancel_promises(mut source ReadableStream, reason ?string) {
	for mut branch in source.tee_branches_ {
		if !isnil(branch.tee_cancel_promise_) && branch.tee_cancel_promise_.state() == .pending {
			mut promise := branch.tee_cancel_promise_
			if error_reason := reason {
				promise.reject(error_reason)
			} else {
				promise.resolve()
			}
		}
	}
}

fn close_tee_branches(mut source ReadableStream) {
	mut any_branch_open := false
	for mut branch in source.tee_branches_ {
		if branch.tee_cancelled_ {
			continue
		}
		any_branch_open = true
		branch.close()
	}
	if any_branch_open {
		settle_tee_cancel_promises(mut source, none)
	}
}

fn error_tee_branches(mut source ReadableStream, reason string) {
	for mut branch in source.tee_branches_ {
		if !branch.tee_cancelled_ {
			branch.error(reason)
		}
	}
	settle_tee_cancel_promises(mut source, reason)
}

fn continue_byte_tee_after_read(mut source ReadableStream) {
	source.tee_reading_ = false
	if source.tee_read_again_1_ {
		pump_readable_tee_branch(mut source.tee_branches_[0])
	} else if source.tee_read_again_2_ {
		pump_readable_tee_branch(mut source.tee_branches_[1])
	}
}

fn close_byte_tee_branches_after_byob_read(mut source ReadableStream, byob_branch_index int) {
	other_branch_index := if byob_branch_index == 1 { 2 } else { 1 }
	mut byob_branch := source.tee_branches_[byob_branch_index - 1]
	mut other_branch := source.tee_branches_[other_branch_index - 1]
	if !byob_branch.tee_cancelled_ {
		mut controller := byob_branch.byte_controller_
		readable_byte_stream_controller_close(mut controller) or {
			error_tee_branches(mut source, err.msg())
			return
		}
		if controller.pending_pull_intos_.len > 0 {
			readable_byte_stream_controller_respond(mut controller, 0) or {
				error_tee_branches(mut source, err.msg())
				return
			}
		}
	}
	if !other_branch.tee_cancelled_ {
		mut controller := other_branch.byte_controller_
		readable_byte_stream_controller_close(mut controller) or {
			error_tee_branches(mut source, err.msg())
			return
		}
		if controller.pending_pull_intos_.len > 0 {
			readable_byte_stream_controller_respond(mut controller, 0) or {
				error_tee_branches(mut source, err.msg())
				return
			}
		}
	}
	if !byob_branch.tee_cancelled_ || !other_branch.tee_cancelled_ {
		settle_tee_cancel_promises(mut source, none)
	}
}

fn pump_readable_byte_tee_source(mut source ReadableStream) {
	if !source.tee_reading_ {
		return
	}
	if !isnil(source.tee_byob_request_) {
		request := source.tee_byob_request_
		if request.state() == .pending {
			return
		}
		source.tee_byob_request_ = unsafe { nil }
		byob_branch_index := source.tee_byob_branch_
		source.tee_byob_branch_ = 0
		if request.state() == .rejected {
			source.tee_reading_ = false
			error_tee_branches(mut source, request.reason())
			return
		}
		source.tee_read_again_1_ = false
		source.tee_read_again_2_ = false
		result := request.result()
		if result.done {
			source.tee_reading_ = false
			close_byte_tee_branches_after_byob_read(mut source, byob_branch_index)
			return
		}

		other_branch_index := if byob_branch_index == 1 { 2 } else { 1 }
		mut byob_branch := source.tee_branches_[byob_branch_index - 1]
		mut other_branch := source.tee_branches_[other_branch_index - 1]
		other_cancelled := other_branch.tee_cancelled_
		byob_cancelled := byob_branch.tee_cancelled_
		mut cloned_chunk := []u8{}
		if !other_cancelled {
			cloned_chunk = result.value.clone()
		}
		if !byob_cancelled {
			// The source BYOB descriptor was constructed over this branch's
			// request view, matching the transferred backing store upstream.
			mut controller := byob_branch.byte_controller_
			readable_byte_stream_controller_respond(mut controller, u64(result.value.len)) or {
				source.tee_reading_ = false
				error_tee_branches(mut source, err.msg())
				return
			}
		}
		if !other_cancelled {
			mut controller := other_branch.byte_controller_
			controller.enqueue(cloned_chunk) or {
				source.tee_reading_ = false
				error_tee_branches(mut source, err.msg())
				return
			}
		}
		continue_byte_tee_after_read(mut source)
		return
	}

	if isnil(source.tee_read_request_) {
		return
	}
	request := source.tee_read_request_
	if request.state() == .pending {
		return
	}
	source.tee_read_request_ = unsafe { nil }
	if request.state() == .rejected {
		source.tee_reading_ = false
		error_tee_branches(mut source, request.reason())
		return
	}
	source.tee_read_again_1_ = false
	source.tee_read_again_2_ = false
	result := request.result()
	if result.done {
		source.tee_reading_ = false
		close_tee_branches(mut source)
		return
	}
	if result.value.kind != .bytes {
		source.tee_reading_ = false
		error_tee_branches(mut source, 'TypeError: byte tee received a non-byte chunk')
		return
	}
	branch1_cancelled := source.tee_branches_[0].tee_cancelled_
	branch2_cancelled := source.tee_branches_[1].tee_cancelled_
	mut chunk2 := unsafe { result.value.bytes_ }
	if !branch1_cancelled && !branch2_cancelled {
		chunk2 = result.value.bytes_.clone()
	}
	if !branch1_cancelled {
		mut controller := source.tee_branches_[0].byte_controller_
		controller.enqueue(result.value.bytes_) or {
			source.tee_reading_ = false
			error_tee_branches(mut source, err.msg())
			return
		}
	}
	if !branch2_cancelled {
		mut controller := source.tee_branches_[1].byte_controller_
		controller.enqueue(chunk2) or {
			source.tee_reading_ = false
			error_tee_branches(mut source, err.msg())
			return
		}
	}
	continue_byte_tee_after_read(mut source)
}

// The V promise records settle synchronously, but these pumps preserve
// Ladybird's tee read/read-again state machines and demand-driven buffering.
fn pump_readable_tee_source(mut source ReadableStream) {
	if source.byte_stream_ {
		pump_readable_byte_tee_source(mut source)
		return
	}
	if !source.tee_reading_ || isnil(source.tee_read_request_) {
		return
	}
	request := source.tee_read_request_
	if request.state() == .pending {
		return
	}
	source.tee_read_request_ = unsafe { nil }
	if request.state() == .rejected {
		source.tee_reading_ = false
		error_tee_branches(mut source, request.reason())
		return
	}
	result := request.result()
	if result.done {
		source.tee_reading_ = false
		close_tee_branches(mut source)
		return
	}

	// Tee read-request chunk steps clear readAgain before enqueueing. A branch
	// which still desires data sets it again through its pull algorithm.
	source.tee_read_again_ = false
	for mut branch in source.tee_branches_ {
		if branch.tee_cancelled_ || branch.state_ != .readable {
			continue
		}
		if source.byte_stream_ {
			mut controller := branch.byte_controller_
			chunk := if branch.tee_branch_index_ == 2 {
				result.value.bytes_.clone()
			} else {
				result.value.bytes_
			}
			controller.enqueue(chunk) or {
				source.tee_reading_ = false
				error_tee_branches(mut source, err.msg())
				cancel_result := source.cancel_internal(string_value(err.msg()))
				if cancel_result.state() == .rejected {
					settle_tee_cancel_promises(mut source, cancel_result.reason())
				}
				return
			}
		} else {
			chunk := if branch.tee_branch_index_ == 2 && source.tee_clone_branch2_ {
				structured_clone(result.value)
			} else {
				result.value
			}
			mut controller := branch.default_controller_
			controller.enqueue(chunk) or {
				source.tee_reading_ = false
				error_tee_branches(mut source, err.msg())
				cancel_result := source.cancel_internal(string_value(err.msg()))
				if cancel_result.state() == .rejected {
					settle_tee_cancel_promises(mut source, cancel_result.reason())
				}
				return
			}
		}
	}
	source.tee_reading_ = false
	if source.tee_read_again_ {
		pump_readable_tee_branch(mut source.tee_branches_[0])
	}
}

fn switch_byte_tee_to_default_reader(mut source ReadableStream) ! {
	if source.reader_kind_ == .byob && !isnil(source.byob_reader_) {
		mut reader := source.byob_reader_
		if reader.read_into_requests_.len != 0 {
			return error('InternalError: Cannot switch a byte tee with a pending BYOB read')
		}
		reader.release_lock()!
	}
	if source.reader_kind_ != .default_reader || isnil(source.default_reader_) {
		_ = source.get_default_reader()!
	}
}

fn switch_byte_tee_to_byob_reader(mut source ReadableStream) ! {
	if source.reader_kind_ == .default_reader && !isnil(source.default_reader_) {
		mut reader := source.default_reader_
		if source.pending_reads_.len != 0 {
			return error('InternalError: Cannot switch a byte tee with a pending default read')
		}
		reader.release_lock()!
	}
	if source.reader_kind_ != .byob || isnil(source.byob_reader_) {
		_ = source.get_byob_reader()!
	}
}

fn pump_readable_byte_tee_branch(mut branch ReadableStream, mut source ReadableStream) {
	if source.tee_reading_ {
		if branch.tee_branch_index_ == 1 {
			source.tee_read_again_1_ = true
		} else {
			source.tee_read_again_2_ = true
		}
		return
	}
	source.tee_reading_ = true
	mut controller := branch.byte_controller_
	if byob_request := readable_byte_stream_controller_get_byob_request(mut controller) {
		view := byob_request.view() or {
			source.tee_reading_ = false
			error_tee_branches(mut source, 'TypeError: Byte tee BYOB request has no view')
			return
		}
		switch_byte_tee_to_byob_reader(mut source) or {
			source.tee_reading_ = false
			error_tee_branches(mut source, err.msg())
			return
		}
		source.tee_byob_branch_ = branch.tee_branch_index_
		mut reader := source.byob_reader_
		source.tee_byob_request_ = reader.read_into_existing_view(view, 1)
	} else {
		switch_byte_tee_to_default_reader(mut source) or {
			source.tee_reading_ = false
			error_tee_branches(mut source, err.msg())
			return
		}
		mut reader := source.default_reader_
		source.tee_read_request_ = reader.read()
	}
	pump_readable_byte_tee_source(mut source)
}

fn pump_readable_tee_branch(mut branch ReadableStream) {
	if isnil(branch.tee_source_) || branch.tee_cancelled_ {
		return
	}
	mut source := branch.tee_source_
	if source.byte_stream_ {
		pump_readable_byte_tee_branch(mut branch, mut source)
		return
	}
	if source.tee_reading_ {
		source.tee_read_again_ = true
		return
	}
	if source.tee_branches_.all(it.tee_cancelled_) {
		return
	}
	source.tee_reading_ = true
	source.tee_read_request_ = source.read_internal()
	pump_readable_tee_source(mut source)
}

fn (mut source ReadableStream) tee_with_clone(clone_for_branch2 bool) !ReadableStreamPair {
	if source.locked() {
		return error('TypeError: Cannot tee a locked ReadableStream')
	}
	// Both tee algorithms acquire a default reader initially. Byte tees may
	// later switch it to a BYOB reader when a branch supplies a BYOB view.
	_ = source.get_default_reader()!
	type_ := if source.byte_stream_ {
		UnderlyingSourceType.bytes
	} else {
		UnderlyingSourceType.default_source
	}
	mut branch1 := ReadableStream.create(source.realm_, UnderlyingSource{
		type_: type_
	}, QueuingStrategy{})!
	mut branch2 := ReadableStream.create(source.realm_, UnderlyingSource{
		type_: type_
	}, QueuingStrategy{})!
	branch1.tee_source_ = &source
	branch1.tee_branch_index_ = 1
	branch2.tee_source_ = &source
	branch2.tee_branch_index_ = 2
	source.disturbed_ = true
	source.tee_clone_branch2_ = clone_for_branch2
	source.tee_branches_ = [branch1, branch2]
	if source.state_ == .errored {
		error_tee_branches(mut source, source.stored_error_)
	} else {
		branch1.call_pull_if_needed()
		branch2.call_pull_if_needed()
	}
	return ReadableStreamPair{
		first: branch1
		second: branch2
	}
}

pub fn (mut source ReadableStream) tee() !ReadableStreamPair {
	return source.tee_with_clone(true)
}

fn cancel_tee_branch(mut branch ReadableStream, reason Value) &VoidPromise {
	if branch.tee_cancelled_ {
		return branch.tee_cancel_promise_
	}
	branch.tee_cancelled_ = true
	branch.tee_cancel_reason_ = reason
	branch.queue_.reset()
	branch.close_internal()
	branch.tee_cancel_promise_ = VoidPromise.pending_in(branch.realm_)
	mut source := branch.tee_source_
	mut other := &ReadableStream(unsafe { nil })
	for mut candidate in source.tee_branches_ {
		if candidate.tee_branch_index_ != branch.tee_branch_index_ {
			other = candidate
			break
		}
	}
	if !isnil(other) && other.tee_cancelled_ {
		mut reasons := []Value{cap: source.tee_branches_.len}
		for candidate in source.tee_branches_ {
			reasons << candidate.tee_cancel_reason_
		}
		composite := array_value(reasons)
		result := source.cancel_internal(composite)
		if result.state() == .rejected {
			mut own := branch.tee_cancel_promise_
			own.reject(result.reason())
			mut theirs := other.tee_cancel_promise_
			theirs.reject(result.reason())
		} else {
			mut own := branch.tee_cancel_promise_
			own.resolve()
			mut theirs := other.tee_cancel_promise_
			theirs.resolve()
		}
	}
	return branch.tee_cancel_promise_
}

pub struct PackedMessage {
pub:
	type_ string
	value Value
}

pub type MessageEventListener = fn (PackedMessage)

@[heap]
pub struct MessagePort {
mut:
	messages_        []PackedMessage
	listeners_       []MessageEventListener
	readable_target_ &ReadableStream = unsafe { nil }
	writable_target_ &WritableStream = unsafe { nil }
	closed_          bool
}

pub fn MessagePort.create() &MessagePort {
	return &MessagePort{}
}

pub fn (port &MessagePort) messages() []PackedMessage {
	mut result := []PackedMessage{cap: port.messages_.len}
	for message in port.messages_ {
		result << PackedMessage{
			type_: message.type_
			value: message.value.clone()
		}
	}
	return result
}

pub fn (mut port MessagePort) close() {
	port.closed_ = true
}

pub fn pack_and_post_message(mut port MessagePort, type_ string, value Value) ! {
	if port.closed_ {
		return error('InvalidStateError: MessagePort is closed')
	}
	message := PackedMessage{
		type_: type_
		value: structured_clone(value)
	}
	port.messages_ << message
	for listener in port.listeners_ {
		listener(PackedMessage{
			type_: message.type_
			value: message.value
		})
	}
	if type_ == 'pull' && !isnil(port.writable_target_) {
		mut target := port.writable_target_
		target.message_backpressure_ = true
		target.process_queue()
	}
	if type_ in ['chunk', 'close', 'error'] && !isnil(port.readable_target_) {
		mut target := port.readable_target_
		receive_cross_realm_message(mut target, message)
	}
	if type_ == 'error' && !isnil(port.writable_target_) {
		mut target := port.writable_target_
		mut controller := target.controller_
		writable_stream_default_controller_error_if_needed(mut controller, message.value)
	}
	if type_ in ['close', 'error'] {
		port.close()
	}
}

pub fn pack_and_post_message_handling_error(mut port MessagePort, type_ string, value Value) {
	pack_and_post_message(mut port, type_, value) or {
		if !port.closed_ {
			port.messages_ << PackedMessage{
				type_: 'error'
				value: string_value(err.msg())
			}
		}
	}
}

pub fn (mut source ReadableStream) transfer() !&ReadableStream {
	if source.locked() {
		return error('DataCloneError: Cannot transfer a locked ReadableStream')
	}
	mut port := MessagePort.create()
	mut writable_endpoint := &WritableStream{}
	set_up_cross_realm_transform_writable(mut writable_endpoint, mut port)
	mut proxy := &ReadableStream{}
	set_up_cross_realm_transform_readable(mut proxy, mut port)
	_ = source.pipe_to(mut writable_endpoint, StreamPipeOptions{})
	return proxy
}

pub fn (mut destination WritableStream) transfer() !&WritableStream {
	if destination.locked() {
		return error('DataCloneError: Cannot transfer a locked WritableStream')
	}
	mut port := MessagePort.create()
	mut readable_endpoint := &ReadableStream{}
	set_up_cross_realm_transform_readable(mut readable_endpoint, mut port)
	mut proxy := &WritableStream{}
	set_up_cross_realm_transform_writable(mut proxy, mut port)
	_ = readable_endpoint.pipe_to(mut destination, StreamPipeOptions{})
	return proxy
}
