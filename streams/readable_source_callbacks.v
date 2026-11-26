// SPDX-License-Identifier: BSD-2-Clause
module streams

import webidl

pub struct ReadableStreamControllerHandle {
pub:
	default_controller ?&ReadableStreamDefaultController
	byte_controller ?&ReadableByteStreamController
}

// The source GC::Function callbacks can also be traced records, without a
// process-wide V closure capture retaining an embedder and its author values.
pub interface ReadableSourceCallbacks {
mut:
	start_readable_source(ReadableStreamControllerHandle) !&webidl.Promise
	pull_readable_source(ReadableStreamControllerHandle) !&webidl.Promise
	cancel_readable_source(Value) !&webidl.Promise
}

fn (stream &ReadableStream) controller_handle() ReadableStreamControllerHandle {
	if stream.byte_stream_ { return ReadableStreamControllerHandle{byte_controller: stream.byte_controller_} }
	return ReadableStreamControllerHandle{default_controller: stream.default_controller_}
}
