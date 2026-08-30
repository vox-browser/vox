// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Direct translations of the readable-stream abstract-operation entry points.
// The standalone port uses typed Value records and synchronously settled
// promises, while retaining the upstream state transitions and controller slots.
module streams

pub type ReadChunkSteps = fn (Value)
pub type ReadCloseSteps = fn ()
pub type ReadErrorSteps = fn (Value)

pub struct ReadLoopReadRequest {
pub:
	on_chunk_steps ?ReadChunkSteps
	on_close_steps ?ReadCloseSteps
	on_error_steps ?ReadErrorSteps
}

pub fn (request &ReadLoopReadRequest) on_chunk(chunk Value) {
	if callback := request.on_chunk_steps {
		callback(chunk.clone())
	}
}

pub fn (request &ReadLoopReadRequest) on_close() {
	if callback := request.on_close_steps {
		callback()
	}
}

pub fn (request &ReadLoopReadRequest) on_error(reason Value) {
	if callback := request.on_error_steps {
		callback(reason.clone())
	}
}

pub struct ReadableStreamTeeReadRequest {
pub:
	branch1           &ReadableStream = unsafe { nil }
	branch2           &ReadableStream = unsafe { nil }
	clone_for_branch2 bool
}

pub fn (mut request ReadableStreamTeeReadRequest) on_chunk(chunk Value) {
	if !isnil(request.branch1) && request.branch1.state_ == .readable {
		mut branch := request.branch1
		mut controller := request.branch1.default_controller_
		controller.enqueue(chunk.clone()) or { branch.error(err.msg()) }
	}
	if !isnil(request.branch2) && request.branch2.state_ == .readable {
		mut branch := request.branch2
		mut controller := request.branch2.default_controller_
		second_chunk := if request.clone_for_branch2 { structured_clone(chunk) } else { chunk.clone() }
		controller.enqueue(second_chunk) or { branch.error(err.msg()) }
	}
}

pub fn (mut request ReadableStreamTeeReadRequest) on_close() {
	if !isnil(request.branch1) {
		mut branch := request.branch1
		branch.close()
	}
	if !isnil(request.branch2) {
		mut branch := request.branch2
		branch.close()
	}
}

pub fn (mut request ReadableStreamTeeReadRequest) on_error(reason Value) {
	if !isnil(request.branch1) {
		mut branch := request.branch1
		branch.error(reason.description())
	}
	if !isnil(request.branch2) {
		mut branch := request.branch2
		branch.error(reason.description())
	}
}

pub struct ReadableByteStreamTeeDefaultReadRequest {
pub:
	branch1 &ReadableStream = unsafe { nil }
	branch2 &ReadableStream = unsafe { nil }
}

pub fn (mut request ReadableByteStreamTeeDefaultReadRequest) on_chunk(chunk Value) {
	if chunk.kind != .bytes {
		request.on_error(string_value('TypeError: byte tee received a non-byte chunk'))
		return
	}
	if !isnil(request.branch1) && request.branch1.state_ == .readable {
		mut branch := request.branch1
		mut controller := request.branch1.byte_controller_
		controller.enqueue(chunk.bytes_.clone()) or { branch.error(err.msg()) }
	}
	if !isnil(request.branch2) && request.branch2.state_ == .readable {
		mut branch := request.branch2
		mut controller := request.branch2.byte_controller_
		controller.enqueue(chunk.bytes_.clone()) or { branch.error(err.msg()) }
	}
}

pub fn (mut request ReadableByteStreamTeeDefaultReadRequest) on_close() {
	if !isnil(request.branch1) {
		mut branch := request.branch1
		branch.close()
	}
	if !isnil(request.branch2) {
		mut branch := request.branch2
		branch.close()
	}
}

pub fn (mut request ReadableByteStreamTeeDefaultReadRequest) on_error(reason Value) {
	if !isnil(request.branch1) {
		mut branch := request.branch1
		branch.error(reason.description())
	}
	if !isnil(request.branch2) {
		mut branch := request.branch2
		branch.error(reason.description())
	}
}

pub struct ReadableByteStreamTeeBYOBReadRequest {
pub:
	byob_branch  &ReadableStream = unsafe { nil }
	other_branch &ReadableStream = unsafe { nil }
}

pub fn (mut request ReadableByteStreamTeeBYOBReadRequest) on_chunk(chunk Value) {
	if chunk.kind != .bytes {
		request.on_error(string_value('TypeError: byte tee received a non-byte chunk'))
		return
	}
	if !isnil(request.byob_branch) && request.byob_branch.state_ == .readable {
		mut branch := request.byob_branch
		mut controller := request.byob_branch.byte_controller_
		controller.enqueue(chunk.bytes_.clone()) or { branch.error(err.msg()) }
	}
	if !isnil(request.other_branch) && request.other_branch.state_ == .readable {
		mut branch := request.other_branch
		mut controller := request.other_branch.byte_controller_
		controller.enqueue(chunk.bytes_.clone()) or { branch.error(err.msg()) }
	}
}

pub fn (mut request ReadableByteStreamTeeBYOBReadRequest) on_close(_ Value) {
	if !isnil(request.byob_branch) {
		mut branch := request.byob_branch
		branch.close()
	}
	if !isnil(request.other_branch) {
		mut branch := request.other_branch
		branch.close()
	}
}

pub fn (mut request ReadableByteStreamTeeBYOBReadRequest) on_error(reason Value) {
	if !isnil(request.byob_branch) {
		mut branch := request.byob_branch
		branch.error(reason.description())
	}
	if !isnil(request.other_branch) {
		mut branch := request.other_branch
		branch.error(reason.description())
	}
}

pub fn UnderlyingSource.from_value(value Value) !UnderlyingSource {
	if value.kind in [.undefined, .null_] {
		return UnderlyingSource{}
	}
	if value.kind == .string_ && value.text == 'bytes' {
		return UnderlyingSource{
			type_: .bytes
		}
	}
	return error('TypeError: UnderlyingSource must be undefined, null, or the typed bytes marker')
}

pub fn (stream &ReadableStream) is_readable() bool {
	return stream.state_ == .readable
}

pub fn (stream &ReadableStream) is_closed() bool {
	return stream.state_ == .closed
}

pub fn (stream &ReadableStream) is_errored() bool {
	return stream.state_ == .errored
}

pub fn (stream &ReadableStream) is_locked() bool {
	return stream.locked()
}

pub fn (stream &ReadableStream) is_disturbed() bool {
	return stream.disturbed_
}

pub fn (mut stream ReadableStream) get_a_reader(mode ?ReadableStreamReaderMode) !ReadableStreamReader {
	return stream.get_reader(ReadableStreamGetReaderOptions{
		mode: mode
	})
}

pub fn (mut stream ReadableStream) transfer_steps() !&ReadableStream {
	return stream.transfer()
}

pub fn (mut stream ReadableStream) transfer_receiving_steps(mut source ReadableStream) ! {
	proxy := source.transfer()!
	stream.transfer_target_ = proxy
}

pub fn (mut stream ReadableStream) set_default_controller(controller &ReadableStreamDefaultController) {
	stream.default_controller_ = controller
	stream.byte_controller_ = unsafe { nil }
	stream.byte_stream_ = false
}

pub fn (mut stream ReadableStream) set_byte_controller(controller &ReadableByteStreamController) {
	stream.byte_controller_ = controller
	stream.default_controller_ = unsafe { nil }
	stream.byte_stream_ = true
}

pub fn (mut stream ReadableStream) set_stored_error(reason string) {
	stream.stored_error_ = reason
}

pub fn (mut stream ReadableStream) set_reader(reader ReadableStreamReader) {
	stream.reader_kind_ = reader.kind
	stream.default_reader_ = reader.default_reader
	stream.byob_reader_ = reader.byob_reader
}

pub fn (mut stream ReadableStream) set_disturbed(value bool) {
	stream.disturbed_ = value
}

pub fn (mut stream ReadableStream) set_state(value ReadableStreamState) {
	stream.state_ = value
}

pub fn (_ &ReadableStream) primary_interface() string {
	return 'ReadableStream'
}

pub fn (reader &ReadableStreamDefaultReader) reader_stream() ?&ReadableStream {
	if reader.released_ || isnil(reader.stream_) {
		return none
	}
	return reader.stream_
}

pub fn (mut reader ReadableStreamDefaultReader) set_reader_stream(stream ?&ReadableStream) {
	reader.stream_ = stream or { unsafe { nil } }
	reader.released_ = stream == none
}

pub fn (reader &ReadableStreamDefaultReader) closed_promise_capability() &VoidPromise {
	return reader.closed_
}

pub fn (mut reader ReadableStreamDefaultReader) set_closed_promise_capability(promise &VoidPromise) {
	reader.closed_ = promise
}

pub fn (reader &ReadableStreamDefaultReader) read_requests() []&ReadPromise {
	if reader.released_ || isnil(reader.stream_) {
		return []&ReadPromise{}
	}
	return reader.stream_.pending_reads_.clone()
}

pub fn (mut reader ReadableStreamDefaultReader) read_a_chunk(mut request ReadLoopReadRequest) {
	result := reader.read()
	match result.state() {
		.fulfilled {
			read_result := result.result()
			if read_result.done {
				request.on_close()
			} else {
				request.on_chunk(read_result.value)
			}
		}
		.rejected { request.on_error(string_value(result.reason())) }
		.pending {}
	}
}

pub fn (mut reader ReadableStreamDefaultReader) read_all_bytes_deprecated() &ReadPromise {
	bytes := reader.read_all_bytes() or { return ReadPromise.rejected(err.msg()) }
	return ReadPromise.fulfilled(bytes_value(bytes), false)
}

pub fn (mut reader ReadableStreamDefaultReader) set_readable_stream_pipe_to_operation(mut destination WritableStream, options StreamPipeOptions) &VoidPromise {
	if reader.released_ || isnil(reader.stream_) {
		return VoidPromise.rejected('TypeError: Reader has no associated stream')
	}
	mut source := reader.stream_
	reader.release_lock() or { return VoidPromise.rejected(err.msg()) }
	return source.pipe_to(mut destination, options)
}

pub fn (reader &ReadableStreamBYOBReader) byob_reader_stream() ?&ReadableStream {
	if reader.released_ || isnil(reader.stream_) {
		return none
	}
	return reader.stream_
}

pub fn (mut reader ReadableStreamBYOBReader) set_byob_reader_stream(stream ?&ReadableStream) {
	reader.stream_ = stream or { unsafe { nil } }
	reader.released_ = stream == none
}

pub fn (reader &ReadableStreamBYOBReader) byob_closed_promise_capability() &VoidPromise {
	return reader.closed_
}

pub fn (mut reader ReadableStreamBYOBReader) set_byob_closed_promise_capability(promise &VoidPromise) {
	reader.closed_ = promise
}

pub fn (reader &ReadableStreamBYOBReader) read_into_requests() int {
	if reader.released_ || isnil(reader.stream_) {
		return 0
	}
	return if isnil(reader.stream_.pending_byob_) { 0 } else { 1 }
}

pub fn (mut request ReadableStreamBYOBRequest) set_controller(controller ?&ReadableByteStreamController) {
	request.controller_ = controller or { unsafe { nil } }
	request.active_ = controller != none
}

pub fn (mut request ReadableStreamBYOBRequest) set_view(view []u8) {
	request.view_ = view.clone()
}

pub fn (pair ReadableStreamPair) size() int {
	return 2
}

pub fn (pair ReadableStreamPair) at(index int) !&ReadableStream {
	return match index {
		0 { pair.first }
		1 { pair.second }
		else { error('RangeError: ReadableStreamPair index must be 0 or 1') }
	}
}

pub fn reset_queue(mut queue QueueWithSizes) {
	queue.reset()
}

pub fn acquire_readable_stream_byob_reader(mut stream ReadableStream) !&ReadableStreamBYOBReader {
	return stream.get_byob_reader()
}

pub fn acquire_readable_stream_default_reader(mut stream ReadableStream) !&ReadableStreamDefaultReader {
	return stream.get_default_reader()
}

pub fn create_readable_stream(start StartAlgorithm, pull PullAlgorithm, cancel CancelAlgorithm, high_water_mark ?f64, size ?SizeAlgorithm) !&ReadableStream {
	return ReadableStream.construct_impl(UnderlyingSource{
		start: start
		pull: pull
		cancel: cancel
	}, QueuingStrategy{
		high_water_mark: high_water_mark
		size: size
	})
}

pub fn create_readable_stream_with_existing_stream(mut stream ReadableStream, source UnderlyingSource, strategy QueuingStrategy) ! {
	created := ReadableStream.construct_impl(source, strategy)!
	stream = *created
}

pub fn create_readable_byte_stream(start StartAlgorithm, pull PullAlgorithm, cancel CancelAlgorithm) !&ReadableStream {
	return ReadableStream.construct_impl(UnderlyingSource{
		type_: .bytes
		start: start
		pull: pull
		cancel: cancel
	}, QueuingStrategy{})
}

pub fn initialize_readable_stream(mut stream ReadableStream) {
	stream.state_ = .readable
	stream.stored_error_ = ''
	stream.disturbed_ = false
	stream.reader_kind_ = .none
	stream.queue_.reset()
}

pub fn is_readable_stream_locked(stream &ReadableStream) bool {
	return stream.locked()
}

pub fn readable_stream_from_iterable(values []Value) !&ReadableStream {
	return ReadableStream.from(values)
}

pub fn readable_stream_pipe_to(mut source ReadableStream, mut destination WritableStream, prevent_close bool, prevent_abort bool, prevent_cancel bool, signal ?&AbortSignal) &VoidPromise {
	return source.pipe_to(mut destination, StreamPipeOptions{
		prevent_close: prevent_close
		prevent_abort: prevent_abort
		prevent_cancel: prevent_cancel
		signal: signal
	})
}

pub fn readable_stream_tee(mut stream ReadableStream, _ bool) !ReadableStreamPair {
	return stream.tee()
}

pub fn readable_stream_default_tee(mut stream ReadableStream, clone_for_branch2 bool) !ReadableStreamPair {
	_ = clone_for_branch2
	return stream.tee()
}

pub fn readable_byte_stream_tee(mut stream ReadableStream) !ReadableStreamPair {
	if !stream.byte_stream_ {
		return error('TypeError: readable_byte_stream_tee requires a byte stream')
	}
	return stream.tee()
}

pub fn readable_stream_add_read_into_request(mut stream ReadableStream, request &BYOBReadPromise) {
	stream.pending_byob_ = request
}

pub fn readable_stream_add_read_request(mut stream ReadableStream, request &ReadPromise) {
	stream.pending_reads_ << request
}

pub fn readable_stream_cancel(mut stream ReadableStream, reason Value) &VoidPromise {
	return stream.cancel_internal(reason)
}

pub fn readable_stream_close(mut stream ReadableStream) {
	stream.close_internal()
}

pub fn readable_stream_error(mut stream ReadableStream, reason Value) {
	stream.error(reason.description())
}

pub fn readable_stream_fulfill_read_into_request(mut stream ReadableStream, chunk []u8, done bool) {
	if isnil(stream.pending_byob_) {
		return
	}
	mut request := stream.pending_byob_
	request.resolve(chunk, done)
	stream.pending_byob_ = unsafe { nil }
}

pub fn readable_stream_fulfill_read_request(mut stream ReadableStream, chunk Value, done bool) {
	if stream.pending_reads_.len == 0 {
		return
	}
	mut request := stream.pending_reads_[0]
	stream.pending_reads_.delete(0)
	request.resolve(chunk, done)
}

pub fn readable_stream_get_num_read_into_requests(stream &ReadableStream) int {
	return if isnil(stream.pending_byob_) { 0 } else { 1 }
}

pub fn readable_stream_get_num_read_requests(stream &ReadableStream) int {
	return stream.pending_reads_.len
}

pub fn readable_stream_has_byob_reader(stream &ReadableStream) bool {
	return stream.reader_kind_ == .byob
}

pub fn readable_stream_has_default_reader(stream &ReadableStream) bool {
	return stream.reader_kind_ == .default_reader
}

pub fn readable_stream_reader_generic_cancel(mut stream ReadableStream, reason Value) &VoidPromise {
	return stream.cancel_internal(reason)
}

pub fn readable_stream_reader_generic_initialize(mut stream ReadableStream, kind ReaderKind) !ReadableStreamReader {
	return stream.get_reader(ReadableStreamGetReaderOptions{
		mode: if kind == .byob { ReadableStreamReaderMode.byob } else { none }
	})
}

pub fn readable_stream_reader_generic_release(mut stream ReadableStream) {
	if !isnil(stream.default_reader_) {
		mut reader := stream.default_reader_
		reader.release_lock() or {}
	} else if !isnil(stream.byob_reader_) {
		mut reader := stream.byob_reader_
		reader.release_lock() or {}
	}
}

pub fn readable_stream_byob_reader_error_read_into_requests(mut reader ReadableStreamBYOBReader, reason Value) {
	if reader.released_ || isnil(reader.stream_) || isnil(reader.stream_.pending_byob_) {
		return
	}
	mut request := reader.stream_.pending_byob_
	request.reject(reason.description())
	reader.stream_.pending_byob_ = unsafe { nil }
}

pub fn readable_stream_byob_reader_read(mut reader ReadableStreamBYOBReader, view_length int, minimum int) &BYOBReadPromise {
	return reader.read(view_length, minimum)
}

pub fn readable_stream_byob_reader_release(mut reader ReadableStreamBYOBReader) {
	reader.release_lock() or {}
}

pub fn readable_stream_default_reader_error_read_requests(mut reader ReadableStreamDefaultReader, reason Value) {
	if reader.released_ || isnil(reader.stream_) {
		return
	}
	for mut request in reader.stream_.pending_reads_ {
		request.reject(reason.description())
	}
	reader.stream_.pending_reads_.clear()
}

pub fn readable_stream_default_reader_read(mut reader ReadableStreamDefaultReader) &ReadPromise {
	return reader.read()
}

pub fn readable_stream_default_reader_release(mut reader ReadableStreamDefaultReader) {
	reader.release_lock() or {}
}

pub fn set_up_readable_stream_byob_reader(mut reader ReadableStreamBYOBReader, mut stream ReadableStream) ! {
	if stream.locked() || !stream.byte_stream_ {
		return error('TypeError: Cannot set up a BYOB reader for this stream')
	}
	created := stream.get_byob_reader()!
	reader = *created
}

pub fn set_up_readable_stream_default_reader(mut reader ReadableStreamDefaultReader, mut stream ReadableStream) ! {
	if stream.locked() {
		return error('TypeError: Cannot set up a reader for a locked stream')
	}
	created := stream.get_default_reader()!
	reader = *created
}
