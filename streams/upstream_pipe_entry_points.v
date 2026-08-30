// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// ReadableStreamPipeTo and cross-realm transform endpoints. The upstream job
// queue is synchronously drained at this standalone boundary.
module streams

pub type PipeShutdownAction = fn () &VoidPromise
pub type PipeCompletionAction = fn ()

@[heap]
pub struct ReadableStreamPipeTo {
mut:
	promise_          &VoidPromise    = unsafe { nil }
	source_           &ReadableStream = unsafe { nil }
	destination_      &WritableStream = unsafe { nil }
	signal_           &AbortSignal    = unsafe { nil }
	options_          StreamPipeOptions
	unwritten_chunks_ []Value
	shutting_down_    bool
}

pub fn ReadableStreamPipeTo.create(mut source ReadableStream, mut destination WritableStream, options StreamPipeOptions) !&ReadableStreamPipeTo {
	if source.locked() || destination.locked() {
		return error('TypeError: pipe endpoints must be unlocked')
	}
	return &ReadableStreamPipeTo{
		promise_: VoidPromise.pending()
		source_: &source
		destination_: &destination
		options_: options
		signal_: options.signal or { unsafe { nil } }
	}
}

pub fn (mut operation ReadableStreamPipeTo) process() {
	if operation.shutting_down_ || isnil(operation.source_) || isnil(operation.destination_) {
		return
	}
	if isnil(operation.source_.pipe_promise_) {
		mut source := operation.source_
		mut destination := operation.destination_
		operation.promise_ = source.pipe_to(mut destination, operation.options_)
	} else {
		pump_readable_pipe(mut operation.source_)
	}
}

pub fn (mut operation ReadableStreamPipeTo) set_abort_signal(signal &AbortSignal) {
	operation.signal_ = signal
	operation.options_ = StreamPipeOptions{
		prevent_close: operation.options_.prevent_close
		prevent_abort: operation.options_.prevent_abort
		prevent_cancel: operation.options_.prevent_cancel
		signal: signal
	}
}

pub fn (mut operation ReadableStreamPipeTo) shutdown_with_action(action PipeShutdownAction, original_error ?Value) {
	if operation.shutting_down_ {
		return
	}
	operation.shutting_down_ = true
	result := action()
	if result.state() == .rejected {
		operation.finish(string_value(result.reason()))
	} else {
		operation.finish(original_error)
	}
}

pub fn (mut operation ReadableStreamPipeTo) shutdown(reason ?Value) {
	if operation.shutting_down_ {
		return
	}
	operation.shutting_down_ = true
	operation.finish(reason)
}

pub fn (mut operation ReadableStreamPipeTo) read_chunk() {
	if isnil(operation.source_) || operation.source_.state_ != .readable {
		return
	}
	mut source := operation.source_
	result := source.read_internal()
	if result.state() == .fulfilled {
		read_result := result.result()
		if !read_result.done {
			operation.unwritten_chunks_ << read_result.value
		}
	} else if result.state() == .rejected {
		operation.shutdown(string_value(result.reason()))
	}
}

pub fn (mut operation ReadableStreamPipeTo) write_chunk() {
	if operation.unwritten_chunks_.len == 0 || isnil(operation.destination_) {
		return
	}
	chunk := operation.unwritten_chunks_[0]
	operation.unwritten_chunks_.delete(0)
	mut destination := operation.destination_
	result := destination.write_internal(chunk)
	if result.state() == .rejected {
		operation.shutdown(string_value(result.reason()))
	}
}

pub fn (mut operation ReadableStreamPipeTo) write_unwritten_chunks() {
	for operation.unwritten_chunks_.len > 0 && !operation.shutting_down_ {
		operation.write_chunk()
	}
}

pub fn (mut operation ReadableStreamPipeTo) wait_for_pending_writes_to_complete(on_complete PipeCompletionAction) {
	operation.write_unwritten_chunks()
	if operation.unwritten_chunks_.len == 0 {
		on_complete()
	}
}

pub fn (mut operation ReadableStreamPipeTo) finish(reason ?Value) {
	if isnil(operation.promise_) {
		operation.promise_ = VoidPromise.pending()
	}
	mut promise := operation.promise_
	if error_value := reason {
		promise.reject(error_value.description())
	} else {
		promise.resolve()
	}
	if !isnil(operation.source_) && !isnil(operation.destination_) {
		unlock_pipe(mut operation.source_, mut operation.destination_)
	}
}

pub fn (operation &ReadableStreamPipeTo) check_for_error_and_close_states() bool {
	return operation.check_for_forward_errors() || operation.check_for_backward_errors()
		|| operation.check_for_forward_close() || operation.check_for_backward_close()
}

pub fn (operation &ReadableStreamPipeTo) check_for_forward_errors() bool {
	return !isnil(operation.source_) && operation.source_.state_ == .errored
}

pub fn (operation &ReadableStreamPipeTo) check_for_backward_errors() bool {
	return !isnil(operation.destination_)
		&& operation.destination_.state_ in [.erroring, .errored]
}

pub fn (operation &ReadableStreamPipeTo) check_for_forward_close() bool {
	return !isnil(operation.source_) && operation.source_.state_ == .closed
}

pub fn (operation &ReadableStreamPipeTo) check_for_backward_close() bool {
	return !isnil(operation.destination_) && operation.destination_.state_ == .closed
}

pub fn add_message_event_listener(mut port MessagePort, listener MessageEventListener) {
	port.listeners_ << listener
}

pub fn cross_realm_transform_send_error(mut port MessagePort, reason Value) {
	pack_and_post_message_handling_error(mut port, 'error', reason)
}

fn receive_cross_realm_message(mut stream ReadableStream, message PackedMessage) {
	match message.type_ {
		'chunk' {
			if stream.byte_stream_ {
				if message.value.kind != .bytes {
					stream.error('TypeError: Cross-realm byte stream received a non-byte chunk')
					return
				}
				mut controller := stream.byte_controller_
				controller.enqueue(message.value.bytes_) or { stream.error(err.msg()) }
			} else {
				mut controller := stream.default_controller_
				controller.enqueue(message.value) or { stream.error(err.msg()) }
			}
		}
		'close' { stream.close() }
		'error' { stream.error(message.value.description()) }
		else {}
	}
}

pub fn set_up_cross_realm_transform_readable(mut stream ReadableStream, mut port MessagePort) {
	port.readable_target_ = &stream
	for message in port.messages_ {
		receive_cross_realm_message(mut stream, message)
	}
}

pub fn set_up_cross_realm_transform_writable(mut stream WritableStream, mut port MessagePort) {
	stream.owner_kind_ = .message_port
	stream.message_port_ = &port
}
