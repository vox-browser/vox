// Copyright (c) 2023, Matthew Olsson <mattco@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// ReadableStreamDefaultReader.cpp::ReadLoopReadRequest and the deprecated
// Promise wrapper share the actual pending request queue with default reads.
module streams

import webidl

pub interface ReadRequest {
	// The request object itself: pending reads are removed by identity, and
	// == on interface values compares the referenced objects' contents.
	read_request_identity() voidptr
mut:
	on_chunk(Value)
	on_close()
	on_error(webidl.Value)
}

pub fn (promise &ReadPromise) read_request_identity() voidptr {
	return voidptr(promise)
}

pub fn (mut promise ReadPromise) on_chunk(chunk Value) {
	promise.resolve(chunk, false)
}

pub fn (mut promise ReadPromise) on_close() {
	promise.resolve(undefined_value(), true)
}

pub fn (mut promise ReadPromise) on_error(reason webidl.Value) {
	promise.reject_value(reason)
}

pub type ReadLoopSuccessSteps = fn ([]u8)
pub type ReadLoopFailureSteps = fn (webidl.Value)

pub struct ReadLoopChunkBytes {
pub:
	bytes ?[]u8
}

@[heap]
struct ReadLoopReadRequest {
	realm         StreamRealm
	reader        &ReadableStreamDefaultReader
	success_steps ReadLoopSuccessSteps @[required]
	failure_steps ReadLoopFailureSteps @[required]
mut:
	bytes []u8
}

fn (request &ReadLoopReadRequest) read_request_identity() voidptr {
	return voidptr(request)
}

fn (mut request ReadLoopReadRequest) on_chunk(chunk Value) {
	bytes := read_loop_uint8_bytes(request.realm, chunk) or {
		request.failure_steps(webidl.exception_value(err))
		return
	}
	if value := bytes.bytes {
		request.bytes << value
	} else {
		request.failure_steps(webidl.simple_exception_value(webidl.SimpleException{
			type_:   .type_error
			message: 'Chunk data is not Uint8Array'
		}))
		return
	}
	// Source recurses with this same retained request. It does not create
	// default-reader Promise jobs for each chunk in the aggregation loop.
	mut reader := request.reader
	readable_stream_default_reader_read_request(mut reader, mut request)
}

fn (mut request ReadLoopReadRequest) on_close() {
	bytes := request.bytes
	request.bytes = []
	request.success_steps(bytes)
}

fn (mut request ReadLoopReadRequest) on_error(reason webidl.Value) {
	request.failure_steps(reason)
}

fn read_loop_uint8_bytes(realm StreamRealm, chunk Value) !ReadLoopChunkBytes {
	if chunk.kind == .bytes { return ReadLoopChunkBytes{ bytes: chunk.bytes_ } }
	if chunk.kind != .runtime_value { return ReadLoopChunkBytes{} }
	value := chunk.runtime_value_ or { return ReadLoopChunkBytes{} }
	if value.kind == .buffer_source {
		source := value.buffer_value or { return ReadLoopChunkBytes{} }
		if source.kind != .uint8_array { return ReadLoopChunkBytes{} }
		// Source's typed-array witness produces zero bytes when detached/OOB.
		return ReadLoopChunkBytes{ bytes: webidl.get_buffer_source_copy(source) }
	}
	if actual := realm.uint8_array_bytes { return actual(value) }
	return ReadLoopChunkBytes{}
}

pub fn readable_stream_default_reader_read_request(mut reader ReadableStreamDefaultReader, mut request ReadRequest) {
	// ReadableStreamOperations.cpp::readable_stream_default_reader_read.
	assert !reader.released_ && !isnil(reader.stream_), 'Source VERIFY: read request requires an associated stream'
	mut stream := reader.stream_
	stream.disturbed_ = true
	if stream.state_ == .closed {
		request.on_close()
	} else if stream.state_ == .errored {
		request.on_error(stream.stored_error_value())
	} else if stream.byte_stream_ {
		stream.byte_controller_pull_steps_request(mut request)
	} else {
		mut controller := stream.default_controller_
		controller.pull_steps_request(mut request)
	}
}

pub fn (mut reader ReadableStreamDefaultReader) read_all_bytes_with_steps(success ReadLoopSuccessSteps, failure ReadLoopFailureSteps) {
	mut request := &ReadLoopReadRequest{
		realm:         reader.closed_promise_realm()
		reader:        &reader
		success_steps: success
		failure_steps: failure
	}
	readable_stream_default_reader_read_request(mut reader, mut request)
}

pub fn (mut reader ReadableStreamDefaultReader) read_all_bytes_deprecated() &webidl.Promise {
	realm := reader.closed_promise_realm()
	mut promise := webidl.create_promise_for(realm.promise_context())
	reader.read_all_bytes_with_steps(fn [mut promise, realm] (bytes []u8) {
		// Source's ByteBuffer ArrayBuffer overload has a fatal MUST allocation
		// boundary and resolves the actual owning-realm object before reactions.
		buffer := realm.array_buffer_value(bytes) or { panic('Source MUST: read-loop ArrayBuffer allocation failed: ${err.msg()}') }
		promise.resolve(buffer)
	}, fn [mut promise] (reason webidl.Value) {
		promise.reject(reason)
	})
	return promise
}
