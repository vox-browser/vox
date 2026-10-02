// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ReadableStreamPipeTo, ReadableStreamTee, and transferable
// streams from AbstractOperations, ReadableStream, and WritableStream.
module streams

import webidl

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
	if !isnil(source.pipe_operation_) {
		mut operation := source.pipe_operation_
		if signal := operation.abort_signal_ {
			if id := operation.abort_algorithm_id_ {
				mut native := signal.dom_signal()
				native.remove_abort_algorithm(id)
			}
		}
		operation.abort_signal_ = none
		operation.abort_algorithm_id_ = none
	}
	if !isnil(destination.writer_) {
		mut writer := destination.writer_
		writer.release_lock()
	}
	if !isnil(source.default_reader_) {
		mut reader := source.default_reader_
		reader.release_lock() or {}
	} else if source.reader_kind_ == .pipe {
		source.reader_kind_ = .none
	}
	source.pipe_destination_ = unsafe { nil }
	source.pipe_operation_ = unsafe { nil }
	destination.pipe_source_ = unsafe { nil }
}

fn pump_readable_pipe(mut source ReadableStream) {
	if !isnil(source.pipe_operation_) {
		mut operation := source.pipe_operation_
		operation.process()
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
	source.disturbed_ = true
	source.pipe_destination_ = &destination
	destination.pipe_source_ = &source
	source.pipe_options_ = options
	source.pipe_promise_ = VoidPromise.pending_in(source.realm_)
	source.pipe_operation_ = ReadableStreamPipeTo.from_promise(source.pipe_promise_)
	reader.set_readable_stream_pipe_to_operation(source.pipe_operation_)
	mut operation := source.pipe_operation_
	operation.bind(mut source, mut destination, reader, writer)
	if mut signal := options.signal {
		if !signal.aborted() {
			mut native := signal.dom_signal()
			operation.abort_signal_ = signal
			operation.abort_algorithm_id_ = native.add_abort_algorithm(fn [mut operation] () {
				operation.check_for_error_and_close_states()
			})
		}
	}
	pump_readable_pipe(mut source)
	return source.pipe_promise_
}

pub fn (mut source ReadableStream) pipe_through(pair ReadableWritablePair, options StreamPipeOptions) !&ReadableStream {
	if source.locked() {
		return error('TypeError: Source ReadableStream is locked')
	}
	if pair.writable.locked() {
		return error('TypeError: Transform writable side is locked')
	}
	mut writable := pair.writable
	promise := source.pipe_to(mut writable, options)
	mut native := promise.as_webidl_promise()
	webidl.mark_promise_as_handled(mut native)
	return pair.readable
}

fn settle_tee_cancel_promises(mut source ReadableStream, reason ?webidl.Value) {
	for mut branch in source.tee_branches_ {
		if !isnil(branch.tee_cancel_promise_) && branch.tee_cancel_promise_.state() == .pending {
			mut promise := branch.tee_cancel_promise_
			if error_reason := reason {
				promise.reject_value(error_reason)
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

fn error_tee_branches(mut source ReadableStream, reason webidl.Value) {
	for mut branch in source.tee_branches_ {
		if !branch.tee_cancelled_ {
			branch.error_value(reason)
		}
	}
	if source.tee_branches_.any(!it.tee_cancelled_) {
		settle_tee_cancel_promises(mut source, none)
	}
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
			error_tee_branches(mut source, webidl.exception_value(err))
			return
		}
		if controller.pending_pull_intos_.len > 0 {
			readable_byte_stream_controller_respond(mut controller, 0) or {
				error_tee_branches(mut source, webidl.exception_value(err))
				return
			}
		}
	}
	if !other_branch.tee_cancelled_ {
		mut controller := other_branch.byte_controller_
		readable_byte_stream_controller_close(mut controller) or {
			error_tee_branches(mut source, webidl.exception_value(err))
			return
		}
		if controller.pending_pull_intos_.len > 0 {
			readable_byte_stream_controller_respond(mut controller, 0) or {
				error_tee_branches(mut source, webidl.exception_value(err))
				return
			}
		}
	}
	if !byob_branch.tee_cancelled_ || !other_branch.tee_cancelled_ {
		settle_tee_cancel_promises(mut source, none)
	}
}

fn deliver_readable_byte_tee_source(mut source ReadableStream) {
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
			error_tee_branches(mut source, request.as_webidl_promise().result)
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
				error_tee_branches(mut source, webidl.exception_value(err))
				return
			}
		}
		if !other_cancelled {
			mut controller := other_branch.byte_controller_
			controller.enqueue(cloned_chunk) or {
				source.tee_reading_ = false
				error_tee_branches(mut source, webidl.exception_value(err))
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
		if source.realm_.promise_context().job_scheduler == none {
			error_tee_branches(mut source, request.as_webidl_promise().result)
		}
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
		error_tee_branches(mut source, webidl.string_value('TypeError: byte tee received a non-byte chunk'))
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
			error_tee_branches(mut source, webidl.exception_value(err))
			return
		}
	}
	if !branch2_cancelled {
		mut controller := source.tee_branches_[1].byte_controller_
		controller.enqueue(chunk2) or {
			source.tee_reading_ = false
			error_tee_branches(mut source, webidl.exception_value(err))
			return
		}
	}
	continue_byte_tee_after_read(mut source)
}

fn deliver_readable_tee_source(mut source ReadableStream) {
	if source.byte_stream_ {
		deliver_readable_byte_tee_source(mut source)
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
		if source.realm_.promise_context().job_scheduler == none {
			error_tee_branches(mut source, request.as_webidl_promise().result)
		}
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
				error_tee_branches(mut source, webidl.exception_value(err))
				cancel_result := source.cancel_internal(stream_value_from_webidl(webidl.exception_value(err)))
				if cancel_result.state() == .rejected {
					settle_tee_cancel_promises(mut source, cancel_result.as_webidl_promise().result)
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
				error_tee_branches(mut source, webidl.exception_value(err))
				cancel_result := source.cancel_internal(stream_value_from_webidl(webidl.exception_value(err)))
				if cancel_result.state() == .rejected {
					settle_tee_cancel_promises(mut source, cancel_result.as_webidl_promise().result)
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
		reader := source.get_default_reader()!
		observe_tee_reader_closed(mut source, reader.closed())
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
		reader := source.get_byob_reader()!
		observe_tee_reader_closed(mut source, reader.closed())
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
			error_tee_branches(mut source, webidl.string_value('TypeError: Byte tee BYOB request has no view'))
			return
		}
		switch_byte_tee_to_byob_reader(mut source) or {
			source.tee_reading_ = false
			error_tee_branches(mut source, webidl.exception_value(err))
			return
		}
		source.tee_byob_branch_ = branch.tee_branch_index_
		mut reader := source.byob_reader_
		source.tee_byob_request_ = reader.read_into_existing_view(view, 1)
	} else {
		switch_byte_tee_to_default_reader(mut source) or {
			source.tee_reading_ = false
			error_tee_branches(mut source, webidl.exception_value(err))
			return
		}
		mut reader := source.default_reader_
		source.tee_read_request_ = reader.read()
	}
	pump_readable_tee_source(mut source)
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
	reader := source.get_default_reader()!
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
	cancel_promise := VoidPromise.pending_in(source.realm_)
	branch1.tee_cancel_promise_ = cancel_promise
	branch2.tee_cancel_promise_ = cancel_promise
	observe_tee_reader_closed(mut source, reader.closed())
	if source.state_ == .errored && source.realm_.promise_context().job_scheduler == none {
		error_tee_branches(mut source, source.stored_error_value())
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
	if isnil(branch.tee_cancel_promise_) {
		branch.tee_cancel_promise_ = VoidPromise.pending_in(branch.realm_)
	}
	mut source := branch.tee_source_
	// The concrete request class depends on which reader the byte tee currently
	// uses. Constructing it here keeps queued tee work tied to the cancel
	// promise's realm just like the upstream request objects.
	if source.byte_stream_ {
		if source.reader_kind_ == .byob {
			_ = ReadableByteStreamTeeBYOBReadRequest.from_promise(branch.tee_cancel_promise_)
		} else {
			_ = ReadableByteStreamTeeDefaultReadRequest.from_promise(branch.tee_cancel_promise_)
		}
	} else {
		_ = ReadableStreamTeeReadRequest.from_promise(branch.tee_cancel_promise_)
	}
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
		adopt_tee_cancel_result(mut source, result)
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
	return source.transfer_in_realm(source.realm_)
}

pub fn (mut destination WritableStream) transfer() !&WritableStream {
	return destination.transfer_in_realm(destination.realm_)
}
