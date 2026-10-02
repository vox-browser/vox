// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// ReadableStreamPipeTo.cpp: the retained source operation, Promise reactions,
// pending writes, shutdown actions and finalization. Standalone callers use a
// local job trampoline; a bound realm queues these jobs on its actual owner.
module streams

import webidl

fn (mut operation ReadableStreamPipeTo) bind(mut source ReadableStream, mut destination WritableStream, reader &ReadableStreamDefaultReader, writer &WritableStreamDefaultWriter) {
	operation.processing_ = true
	defer { operation.processing_ = false }
	operation.source_ = &source
	operation.destination_ = &destination
	operation.reader_ = reader
	operation.writer_ = writer
	for closed in [reader.closed(), writer.closed()] {
		mut native := closed.as_webidl_promise()
		webidl.react_to_promise(mut native, fn [mut operation] (_ webidl.Value) !webidl.Value {
			operation.after_promise_reaction(fn [mut operation] () { operation.check_for_error_and_close_states() })
			return webidl.undefined_value()
		}, fn [mut operation] (_ webidl.Value) !webidl.Value {
			operation.after_promise_reaction(fn [mut operation] () { operation.check_for_error_and_close_states() })
			return webidl.undefined_value()
		})
	}
}

fn (mut operation ReadableStreamPipeTo) enqueue_microtask(job fn ()) {
	context := operation.promise_realm().promise_context()
	if scheduler := context.job_scheduler {
		scheduler(fn [mut operation, job] () { operation.run_job(job) })
	} else {
		operation.standalone_jobs_ << job
		if !operation.processing_ { operation.run_job(fn () {}) }
	}
}

// A real Promise has already scheduled its reaction. The direct standalone
// adapter still needs to defer that reaction while a read/write call is active.
fn (mut operation ReadableStreamPipeTo) after_promise_reaction(job fn ()) {
	if operation.promise_realm().promise_context().job_scheduler != none {
		operation.run_job(job)
	} else {
		operation.enqueue_microtask(job)
	}
}

fn (mut operation ReadableStreamPipeTo) run_job(job fn ()) {
	if operation.processing_ {
		operation.standalone_jobs_ << job
		return
	}
	operation.processing_ = true
	defer { operation.processing_ = false }
	job()
	for operation.standalone_jobs_.len > 0 {
		next := operation.standalone_jobs_[0]
		operation.standalone_jobs_.delete(0)
		next()
	}
}

fn (mut operation ReadableStreamPipeTo) process() {
	if operation.processing_ || operation.finished_ || isnil(operation.source_) { return }
	operation.run_job(fn [mut operation] () { operation.process_step() })
}

fn (mut operation ReadableStreamPipeTo) process_step() {
	if operation.check_for_error_and_close_states() || operation.reading_ || operation.waiting_ready_ { return }
	mut ready := operation.writer_.ready().as_webidl_promise()
	if ready.is_fulfilled() {
		operation.read_chunk()
		return
	}
	operation.waiting_ready_ = true
	webidl.react_to_promise(mut ready, fn [mut operation] (_ webidl.Value) !webidl.Value {
		operation.after_promise_reaction(fn [mut operation] () {
			operation.waiting_ready_ = false
			operation.read_chunk()
		})
		return webidl.undefined_value()
	}, fn [mut operation] (_ webidl.Value) !webidl.Value {
		operation.after_promise_reaction(fn [mut operation] () {
			operation.waiting_ready_ = false
			operation.check_for_error_and_close_states()
		})
		return webidl.undefined_value()
	})
}

fn (mut operation ReadableStreamPipeTo) read_chunk() {
	if operation.check_for_error_and_close_states() || operation.reading_ { return }
	operation.reading_ = true
	mut reader := operation.reader_
	mut request := reader.read()
	operation.source_.pipe_read_request_ = request
	request.upon_settlement(fn [mut operation] (result ReadResult) {
		operation.reading_ = false
		operation.source_.pipe_read_request_ = unsafe { nil }
		if result.done {
			if !operation.check_for_error_and_close_states() { operation.finish(none) }
			return
		}
		operation.unwritten_chunks_ << result.value
		if operation.check_for_error_and_close_states() { return }
		operation.enqueue_microtask(fn [mut operation] () {
			operation.write_chunk()
			operation.process_step()
		})
	}, fn [mut operation] (_ string) {
		operation.reading_ = false
		operation.source_.pipe_read_request_ = unsafe { nil }
		operation.check_for_error_and_close_states()
	})
}

fn (mut operation ReadableStreamPipeTo) write_chunk() {
	if operation.unwritten_chunks_.len == 0 || (!operation.shutting_down_ && operation.check_for_error_and_close_states()) { return }
	chunk := operation.unwritten_chunks_[0]
	operation.unwritten_chunks_.delete(0)
	mut writer := operation.writer_
	promise := writer.write(chunk)
	mut native := promise.as_webidl_promise()
	webidl.mark_promise_as_handled(mut native)
	operation.last_write_promise_ = promise
}

fn (mut operation ReadableStreamPipeTo) wait_for_pending_writes_to_complete(steps fn ()) {
	last_write := operation.last_write_promise_
	operation.last_write_promise_ = unsafe { nil }
	if isnil(last_write) {
		operation.enqueue_microtask(steps)
		return
	}
	mut native := last_write.as_webidl_promise()
	webidl.react_to_promise(mut native, fn [mut operation, steps] (_ webidl.Value) !webidl.Value {
		operation.after_promise_reaction(steps)
		return webidl.undefined_value()
	}, fn [mut operation, steps] (_ webidl.Value) !webidl.Value {
		operation.after_promise_reaction(steps)
		return webidl.undefined_value()
	})
}

fn (mut operation ReadableStreamPipeTo) shutdown_with_action(action ?fn () &VoidPromise, original_error ?webidl.Value) {
	if operation.shutting_down_ { return }
	operation.shutting_down_ = true
	on_pending_writes_complete := fn [mut operation, action, original_error] () {
		if actual_action := action {
			mut native := actual_action().as_webidl_promise()
			webidl.react_to_promise(mut native, fn [mut operation, original_error] (_ webidl.Value) !webidl.Value {
				operation.after_promise_reaction(fn [mut operation, original_error] () { operation.finish(original_error) })
				return webidl.undefined_value()
			}, fn [mut operation] (reason webidl.Value) !webidl.Value {
				operation.after_promise_reaction(fn [mut operation, reason] () { operation.finish(reason) })
				return webidl.undefined_value()
			})
		} else {
			operation.finish(original_error)
		}
	}
	if operation.destination_.state_ == .writable && !writable_stream_close_queued_or_in_flight(operation.destination_) {
		for operation.unwritten_chunks_.len > 0 { operation.write_chunk() }
		operation.wait_for_pending_writes_to_complete(on_pending_writes_complete)
	} else {
		on_pending_writes_complete()
	}
}

fn (mut operation ReadableStreamPipeTo) finish(reason ?webidl.Value) {
	if operation.finished_ { return }
	operation.finished_ = true
	mut source := operation.source_
	mut destination := operation.destination_
	unlock_pipe(mut source, mut destination)
	mut promise := operation.promise_
	if error_reason := reason { promise.reject_value(error_reason) } else { promise.resolve() }
}

fn (mut operation ReadableStreamPipeTo) check_for_error_and_close_states() bool {
	if operation.shutting_down_ || operation.finished_ { return true }
	mut source := operation.source_
	mut destination := operation.destination_
	options := source.pipe_options_
	if signal := options.signal {
		if signal.aborted() {
			reason := signal.reason()
			operation.shutdown_with_action(fn [mut source, mut destination, options, reason] () &VoidPromise {
				mut actions := []&webidl.Promise{}
				if !options.prevent_abort && destination.state_ == .writable {
					actions << destination.abort_internal(reason).as_webidl_promise()
				}
				if !options.prevent_cancel && source.state_ == .readable {
					actions << source.cancel_internal(reason).as_webidl_promise()
				}
				mut result := VoidPromise.pending_in(source.realm_)
				webidl.wait_for_all(actions, fn [mut result] (_ []webidl.Value) { result.resolve() },
					fn [mut result] (error webidl.Value) { result.reject_value(error) })
				return result
			}, stream_value_to_webidl(reason))
			return true
		}
	}
	if source.state_ == .errored {
		reason := source.stored_error_value()
		if options.prevent_abort { operation.shutdown_with_action(none, reason) }
		else { operation.shutdown_with_action(fn [mut destination, reason] () &VoidPromise { return destination.abort_internal(stream_value_from_webidl(reason)) }, reason) }
		return true
	}
	if destination.state_ == .errored {
		reason := destination.stored_error_value()
		if options.prevent_cancel { operation.shutdown_with_action(none, reason) }
		else { operation.shutdown_with_action(fn [mut source, reason] () &VoidPromise { return source.cancel_internal(stream_value_from_webidl(reason)) }, reason) }
		return true
	}
	if source.state_ == .closed {
		if options.prevent_close { operation.shutdown_with_action(none, none) }
		else { operation.shutdown_with_action(fn [mut operation] () &VoidPromise {
			mut writer := operation.writer_
			return writable_stream_default_writer_close_with_error_propagation(mut writer)
		}, none) }
		return true
	}
	if writable_stream_close_queued_or_in_flight(destination) || destination.state_ == .closed {
		reason := webidl.string_value('TypeError: Destination stream was closed during piping operation')
		if options.prevent_cancel { operation.shutdown_with_action(none, reason) }
		else { operation.shutdown_with_action(fn [mut source, reason] () &VoidPromise { return source.cancel_internal(stream_value_from_webidl(reason)) }, reason) }
		return true
	}
	return false
}
