// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Cross-realm transform endpoints translated from Streams/AbstractOperations.
// The V runtime drains its observable promise records synchronously.
module streams

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
	initialize_readable_stream(mut stream)
	mut controller := ReadableStreamDefaultController{
		stream_: &stream
	}
	set_up_readable_stream_default_controller(mut stream, mut controller, no_op_start_algorithm, no_op_pull_algorithm, no_op_cancel_algorithm, 0, count_size_algorithm) or {
		stream.error(err.msg())
		return
	}
	stream.owner_kind_ = .message_port
	stream.message_port_ = &port
	port.readable_target_ = &stream
	for message in port.messages_ {
		receive_cross_realm_message(mut stream, message)
	}
}

pub fn set_up_cross_realm_transform_writable(mut stream WritableStream, mut port MessagePort) {
	initialize_writable_stream(mut stream)
	mut controller := WritableStreamDefaultController{
		stream_: &stream
		signal_: AbortSignal.create()
	}
	set_up_writable_stream_default_controller(mut stream, mut controller, no_op_start_algorithm, no_op_write_algorithm, no_op_close_algorithm, no_op_abort_algorithm, 1, count_size_algorithm) or {
		stream.start_erroring(err.msg())
		return
	}
	stream.owner_kind_ = .message_port
	stream.message_port_ = &port
	stream.message_backpressure_ = false
	port.writable_target_ = &stream
	// MessagePort queues messages until its receiving endpoint starts. Transfer
	// receiving steps may therefore observe a pull posted during serialization.
	for message in port.messages_ {
		if message.type_ == 'pull' {
			stream.message_backpressure_ = true
		}
	}
	if stream.message_backpressure_ {
		stream.process_queue()
	}
}
