// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Direct translations of the readable-stream abstract operations. The V
// runtime boundary uses typed values and synchronously observable promise
// records while retaining the upstream state transitions and controller slots.
module streams

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
	stream = *proxy
	if !isnil(stream.default_controller_) {
		stream.default_controller_.stream_ = &stream
	}
	if !isnil(stream.byte_controller_) {
		stream.byte_controller_.stream_ = &stream
	}
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
	return reader.stream_.pending_reads_.values()
}

pub fn (mut reader ReadableStreamDefaultReader) read_all_bytes_deprecated() &ReadPromise {
	bytes := reader.read_all_bytes() or { return ReadPromise.rejected(err.msg()) }
	return ReadPromise.fulfilled(bytes_value(bytes), false)
}

pub fn (mut reader ReadableStreamDefaultReader) set_readable_stream_pipe_to_operation(operation voidptr) {
	reader.pipe_to_operation_ = operation
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
	return reader.read_into_requests_.len
}

pub fn (mut request ReadableStreamBYOBRequest) set_controller(controller ?&ReadableByteStreamController) {
	request.controller_ = controller or { unsafe { nil } }
	request.active_ = controller != none
}

pub fn (mut request ReadableStreamBYOBRequest) set_view(view []u8) {
	request.view_ = unsafe { view }
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
	if source.type_ == .bytes {
		return error('TypeError: create_readable_stream_with_existing_stream requires a default source')
	}
	high_water_mark := extract_high_water_mark(strategy, 1)!
	initialize_readable_stream(mut stream)
	mut controller := ReadableStreamDefaultController{
		stream_: &stream
	}
	set_up_readable_stream_default_controller(mut stream, mut controller, source.start or { no_op_start_algorithm }, source.pull or { no_op_pull_algorithm }, source.cancel or { no_op_cancel_algorithm }, high_water_mark, extract_size_algorithm(strategy))!
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
	stream.default_reader_ = unsafe { nil }
	stream.byob_reader_ = unsafe { nil }
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

pub fn readable_stream_tee(mut stream ReadableStream, clone_for_branch2 bool) !ReadableStreamPair {
	if stream.byte_stream_ {
		return stream.tee_with_clone(false)
	}
	return stream.tee_with_clone(clone_for_branch2)
}

pub fn readable_stream_default_tee(mut stream ReadableStream, clone_for_branch2 bool) !ReadableStreamPair {
	return stream.tee_with_clone(clone_for_branch2)
}

pub fn readable_byte_stream_tee(mut stream ReadableStream) !ReadableStreamPair {
	if !stream.byte_stream_ {
		return error('TypeError: readable_byte_stream_tee requires a byte stream')
	}
	return stream.tee_with_clone(false)
}

pub fn readable_stream_add_read_into_request(mut stream ReadableStream, request &BYOBReadPromise) {
	if stream.reader_kind_ == .byob && !isnil(stream.byob_reader_) {
		stream.byob_reader_.read_into_requests_ << request
	}
}

pub fn readable_stream_add_read_request(mut stream ReadableStream, request &ReadPromise) {
	stream.pending_reads_.append(request)
}

pub fn readable_stream_cancel(mut stream ReadableStream, reason Value) &VoidPromise {
	return stream.cancel_internal(reason)
}

pub fn readable_stream_close(mut stream ReadableStream) {
	stream.close_internal()
}

pub fn readable_stream_error(mut stream ReadableStream, reason Value) {
	stream.error_internal(reason.description())
}

pub fn readable_stream_fulfill_read_into_request(mut stream ReadableStream, chunk []u8, done bool) {
	if stream.reader_kind_ != .byob || isnil(stream.byob_reader_) || stream.byob_reader_.read_into_requests_.len == 0 {
		return
	}
	mut request := stream.byob_reader_.read_into_requests_[0]
	stream.byob_reader_.read_into_requests_.delete(0)
	request.resolve(chunk, done)
}

pub fn readable_stream_fulfill_read_request(mut stream ReadableStream, chunk Value, done bool) {
	if stream.pending_reads_.len == 0 {
		return
	}
	mut request := stream.pending_reads_.shift() or { return }
	request.resolve(chunk, done)
}

pub fn readable_stream_get_num_read_into_requests(stream &ReadableStream) int {
	if stream.reader_kind_ != .byob || isnil(stream.byob_reader_) {
		return 0
	}
	return stream.byob_reader_.read_into_requests_.len
}

pub fn readable_stream_get_num_read_requests(stream &ReadableStream) int {
	return stream.pending_reads_.len
}

pub fn readable_stream_has_byob_reader(stream &ReadableStream) bool {
	return stream.reader_kind_ == .byob
}

pub fn readable_stream_has_default_reader(stream &ReadableStream) bool {
	return stream.reader_kind_ in [.default_reader, .pipe, .tee]
}

pub fn readable_stream_reader_generic_cancel(reader ReadableStreamReader, reason Value) &VoidPromise {
	if reader.kind in [.default_reader, .pipe, .tee] && !isnil(reader.default_reader)
		&& !reader.default_reader.released_ && !isnil(reader.default_reader.stream_) {
		mut stream := reader.default_reader.stream_
		return stream.cancel_internal(reason)
	}
	if reader.kind == .byob && !isnil(reader.byob_reader) && !reader.byob_reader.released_
		&& !isnil(reader.byob_reader.stream_) {
		mut stream := reader.byob_reader.stream_
		return stream.cancel_internal(reason)
	}
	return VoidPromise.rejected('TypeError: Reader has no associated stream')
}

pub fn readable_stream_reader_generic_initialize(mut stream ReadableStream, kind ReaderKind) !ReadableStreamReader {
	return stream.get_reader(ReadableStreamGetReaderOptions{
		mode: if kind == .byob { ReadableStreamReaderMode.byob } else { none }
	})
}

pub fn readable_stream_reader_generic_release(reader ReadableStreamReader) {
	if reader.kind in [.default_reader, .pipe, .tee] && !isnil(reader.default_reader) {
		mut default_reader := reader.default_reader
		readable_stream_default_reader_generic_release(mut default_reader)
	} else if reader.kind == .byob && !isnil(reader.byob_reader) {
		mut byob_reader := reader.byob_reader
		readable_stream_byob_reader_generic_release(mut byob_reader)
	}
}

pub fn readable_stream_byob_reader_error_read_into_requests(mut reader ReadableStreamBYOBReader, reason Value) {
	for mut request in reader.read_into_requests_ {
		request.reject(reason.description())
	}
	reader.read_into_requests_.clear()
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
	for mut request in reader.stream_.pending_reads_.values() {
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
	created := ReadableStreamBYOBReader.create(stream.realm_, mut stream)!
	reader = *created
}

pub fn set_up_readable_stream_default_reader(mut reader ReadableStreamDefaultReader, mut stream ReadableStream) ! {
	if stream.locked() {
		return error('TypeError: Cannot set up a reader for a locked stream')
	}
	created := ReadableStreamDefaultReader.create(stream.realm_, mut stream)!
	reader = *created
}
