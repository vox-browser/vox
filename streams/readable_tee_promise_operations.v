// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// ReadableStreamTee.cpp and ReadableStreamOperations.cpp: chunk microtasks,
// the current reader's closed reaction, and adoption of the shared cancel
// Promise. Chunk/body state remains in the canonical retained tee records.
module streams

import webidl

fn pump_readable_tee_source(mut source ReadableStream) {
	if source.tee_delivery_queued_ || !source.tee_reading_ { return }
	mut has_chunk := false
	if source.byte_stream_ && !isnil(source.tee_byob_request_) {
		request := source.tee_byob_request_
		has_chunk = request.state() == .fulfilled && !request.result().done
	} else if !isnil(source.tee_read_request_) {
		request := source.tee_read_request_
		has_chunk = request.state() == .fulfilled && !request.result().done
	}
	if has_chunk {
		if scheduler := source.realm_.promise_context().job_scheduler {
			source.tee_delivery_queued_ = true
			scheduler(fn [mut source] () {
				source.tee_delivery_queued_ = false
				deliver_readable_tee_source(mut source)
			})
			return
		}
	}
	deliver_readable_tee_source(mut source)
}

fn observe_tee_reader_closed(mut source ReadableStream, closed &VoidPromise) {
	mut native := closed.as_webidl_promise()
	webidl.react_to_promise(mut native, fn (_ webidl.Value) !webidl.Value {
		return webidl.undefined_value()
	}, fn [mut source, closed] (reason webidl.Value) !webidl.Value {
		current_closed := if source.reader_kind_ == .byob && !isnil(source.byob_reader_) {
			source.byob_reader_.closed()
		} else if !isnil(source.default_reader_) {
			source.default_reader_.closed()
		} else { &VoidPromise(unsafe { nil }) }
		// A reader replaced by the byte tee rejects its closed Promise during
		// release; that old reader's rejection does not error the branches.
		if voidptr(current_closed) == voidptr(closed) && source.state_ == .errored {
			error_tee_branches(mut source, callback_reason(reason))
		}
		return webidl.undefined_value()
	})
}

fn adopt_tee_cancel_result(mut source ReadableStream, result &VoidPromise) {
	mut native := result.as_webidl_promise()
	webidl.react_to_promise(mut native, fn [mut source] (_ webidl.Value) !webidl.Value {
		settle_tee_cancel_promises(mut source, none)
		return webidl.undefined_value()
	}, fn [mut source] (reason webidl.Value) !webidl.Value {
		settle_tee_cancel_promises(mut source, callback_reason(reason))
		return webidl.undefined_value()
	})
}
