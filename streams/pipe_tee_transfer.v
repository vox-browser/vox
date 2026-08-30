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
	if source.reader_kind_ == .pipe {
		source.reader_kind_ = .none
	}
	if !isnil(destination.writer_) {
		mut writer := destination.writer_
		writer.release_lock()
	}
	source.pipe_destination_ = unsafe { nil }
	destination.pipe_source_ = unsafe { nil }
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
	if isnil(source.pipe_destination_) || isnil(source.pipe_promise_)
		|| source.pipe_promise_.state() != .pending {
		return
	}
	mut destination := source.pipe_destination_
	if signal := source.pipe_options_.signal {
		if signal.aborted() {
			reason := signal.reason()
			if !source.pipe_options_.prevent_abort {
				destination.abort_internal(reason)
			}
			if !source.pipe_options_.prevent_cancel {
				source.cancel_internal(reason)
			}
			fail_pipe(mut source, reason.description())
			return
		}
	}
	if source.state_ == .errored {
		if !source.pipe_options_.prevent_abort {
			destination.abort_internal(string_value(source.stored_error_))
		}
		fail_pipe(mut source, source.stored_error_)
		return
	}
	if destination.state_ == .errored || destination.state_ == .erroring {
		if !source.pipe_options_.prevent_cancel {
			source.cancel_internal(string_value(destination.stored_error_))
		}
		fail_pipe(mut source, destination.stored_error_)
		return
	}
	for !source.queue_.is_empty() {
		value := source.queue_.dequeue_value() or {
			fail_pipe(mut source, err.msg())
			return
		}
		source.disturbed_ = true
		write := destination.write_internal(value)
		if write.state() == .rejected {
			if !source.pipe_options_.prevent_cancel {
				source.cancel_internal(string_value(write.reason()))
			}
			fail_pipe(mut source, write.reason())
			return
		}
	}
	if source.close_requested_ && source.queue_.is_empty() {
		source.close_internal()
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
	}
}

pub fn (mut source ReadableStream) pipe_to(mut destination WritableStream, options StreamPipeOptions) &VoidPromise {
	if source.locked() {
		return VoidPromise.rejected('TypeError: Source ReadableStream is locked')
	}
	if destination.locked() {
		return VoidPromise.rejected('TypeError: Destination WritableStream is locked')
	}
	if voidptr(&source) == voidptr(&destination) {
		return VoidPromise.rejected('TypeError: A stream cannot be piped to itself')
	}
	writer := destination.get_writer() or { return VoidPromise.rejected(err.msg()) }
	_ = writer
	source.reader_kind_ = .pipe
	source.pipe_destination_ = &destination
	destination.pipe_source_ = &source
	source.pipe_options_ = options
	source.pipe_promise_ = VoidPromise.pending()
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

pub fn (mut source ReadableStream) tee() !ReadableStreamPair {
	if source.locked() {
		return error('TypeError: Cannot tee a locked ReadableStream')
	}
	type_ := if source.byte_stream_ {
		UnderlyingSourceType.bytes
	} else {
		UnderlyingSourceType.default_source
	}
	mut branch1 := ReadableStream.construct_impl(UnderlyingSource{
		type_: type_
	}, QueuingStrategy{
		high_water_mark: source.high_water_mark_
	})!
	mut branch2 := ReadableStream.construct_impl(UnderlyingSource{
		type_: type_
	}, QueuingStrategy{
		high_water_mark: source.high_water_mark_
	})!
	branch1.tee_source_ = &source
	branch1.tee_branch_index_ = 1
	branch2.tee_source_ = &source
	branch2.tee_branch_index_ = 2
	source.reader_kind_ = .tee
	source.disturbed_ = true
	for !source.queue_.is_empty() {
		value := source.queue_.dequeue_value()!
		if source.byte_stream_ {
			mut branch1_controller := branch1.byte_controller_
			branch1_controller.enqueue(value.bytes_.clone())!
			mut branch2_controller := branch2.byte_controller_
			branch2_controller.enqueue(value.bytes_.clone())!
		} else {
			mut branch1_controller := branch1.default_controller_
			branch1_controller.enqueue(value.clone())!
			mut branch2_controller := branch2.default_controller_
			branch2_controller.enqueue(structured_clone(value))!
		}
	}
	source.tee_branches_ = [branch1, branch2]
	if source.state_ == .closed || source.close_requested_ {
		branch1.close()
		branch2.close()
	} else if source.state_ == .errored {
		branch1.error(source.stored_error_)
		branch2.error(source.stored_error_)
	}
	return ReadableStreamPair{
		first:  branch1
		second: branch2
	}
}

fn cancel_tee_branch(mut branch ReadableStream, reason Value) &VoidPromise {
	if branch.tee_cancelled_ {
		return branch.tee_cancel_promise_
	}
	branch.tee_cancelled_ = true
	branch.tee_cancel_reason_ = reason.clone()
	branch.queue_.reset()
	branch.close_internal()
	branch.tee_cancel_promise_ = VoidPromise.pending()
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
			reasons << candidate.tee_cancel_reason_.clone()
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
	messages_       []PackedMessage
	listeners_      []MessageEventListener
	readable_target_ &ReadableStream = unsafe { nil }
	closed_         bool
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
			value: message.value.clone()
		})
	}
	if !isnil(port.readable_target_) {
		mut target := port.readable_target_
		receive_cross_realm_message(mut target, message)
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
	type_ := if source.byte_stream_ {
		UnderlyingSourceType.bytes
	} else {
		UnderlyingSourceType.default_source
	}
	mut proxy := ReadableStream.construct_impl(UnderlyingSource{
		type_: type_
	}, QueuingStrategy{
		high_water_mark: source.high_water_mark_
	})!
	for !source.queue_.is_empty() {
		value := source.queue_.dequeue_value()!
		if source.byte_stream_ {
			mut proxy_controller := proxy.byte_controller_
			proxy_controller.enqueue(value.bytes_.clone())!
		} else {
			mut proxy_controller := proxy.default_controller_
			proxy_controller.enqueue(structured_clone(value))!
		}
	}
	source.reader_kind_ = .transfer
	source.disturbed_ = true
	source.transfer_target_ = proxy
	if source.state_ == .closed || source.close_requested_ {
		proxy.close()
	} else if source.state_ == .errored {
		proxy.error(source.stored_error_)
	}
	return proxy
}

pub fn (mut destination WritableStream) transfer() !&WritableStream {
	if destination.locked() {
		return error('DataCloneError: Cannot transfer a locked WritableStream')
	}
	mut proxy := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	proxy.owner_kind_ = .transfer_proxy
	proxy.transfer_destination_ = &destination
	destination.transfer_locked_ = true
	return proxy
}
