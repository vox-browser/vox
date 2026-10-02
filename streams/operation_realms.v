// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Promise-owning stream operations use the promise's realm when they run
// queued work. These compact records mirror the ownership-bearing portions of
// Ladybird's pipe and tee request classes. Pipe state and reactions belong to
// the retained operation; tee reader state belongs to its source stream.
module streams

pub fn promise_realm(promise &VoidPromise) StreamRealm {
	return promise.realm()
}

pub struct ReadableStreamGenericReaderMixin {
mut:
	closed_promise_ &VoidPromise = unsafe { nil }
}

pub fn ReadableStreamGenericReaderMixin.from_promise(promise &VoidPromise) ReadableStreamGenericReaderMixin {
	return ReadableStreamGenericReaderMixin{
		closed_promise_: promise
	}
}

pub fn (reader &ReadableStreamGenericReaderMixin) closed_promise_realm() StreamRealm {
	return promise_realm(reader.closed_promise_)
}

@[heap]
pub struct ReadableStreamPipeTo {
mut:
	promise_ &VoidPromise = unsafe { nil }
	source_ &ReadableStream = unsafe { nil }
	destination_ &WritableStream = unsafe { nil }
	reader_ &ReadableStreamDefaultReader = unsafe { nil }
	writer_ &WritableStreamDefaultWriter = unsafe { nil }
	last_write_promise_ &VoidPromise = unsafe { nil }
	unwritten_chunks_ []Value
	shutting_down_ bool
	finished_ bool
	reading_ bool
	waiting_ready_ bool
	processing_ bool
	standalone_jobs_ []fn ()
}

pub fn ReadableStreamPipeTo.from_promise(promise &VoidPromise) &ReadableStreamPipeTo {
	return &ReadableStreamPipeTo{
		promise_: promise
	}
}

pub fn (operation &ReadableStreamPipeTo) promise_realm() StreamRealm {
	return promise_realm(operation.promise_)
}

@[heap]
pub struct ReadableStreamTeeReadRequest {
	cancel_promise_ &VoidPromise
}

pub fn ReadableStreamTeeReadRequest.from_promise(promise &VoidPromise) &ReadableStreamTeeReadRequest {
	return &ReadableStreamTeeReadRequest{
		cancel_promise_: promise
	}
}

pub fn (request &ReadableStreamTeeReadRequest) promise_realm() StreamRealm {
	return promise_realm(request.cancel_promise_)
}

@[heap]
pub struct ReadableByteStreamTeeDefaultReadRequest {
	cancel_promise_ &VoidPromise
}

pub fn ReadableByteStreamTeeDefaultReadRequest.from_promise(promise &VoidPromise) &ReadableByteStreamTeeDefaultReadRequest {
	return &ReadableByteStreamTeeDefaultReadRequest{
		cancel_promise_: promise
	}
}

pub fn (request &ReadableByteStreamTeeDefaultReadRequest) promise_realm() StreamRealm {
	return promise_realm(request.cancel_promise_)
}

@[heap]
pub struct ReadableByteStreamTeeBYOBReadRequest {
	cancel_promise_ &VoidPromise
}

pub fn ReadableByteStreamTeeBYOBReadRequest.from_promise(promise &VoidPromise) &ReadableByteStreamTeeBYOBReadRequest {
	return &ReadableByteStreamTeeBYOBReadRequest{
		cancel_promise_: promise
	}
}

pub fn (request &ReadableByteStreamTeeBYOBReadRequest) promise_realm() StreamRealm {
	return promise_realm(request.cancel_promise_)
}
