// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ReadableStream, its generic/default readers and controller,
// ReadableStreamAsyncIterator, and the corresponding abstract operations.
module streams

pub enum ReadableStreamState {
	readable
	closed
	errored
}

pub enum ReaderKind {
	none
	default_reader
	byob
	pipe
	tee
	transfer
}

pub enum ReadableStreamReaderMode {
	byob
}

pub struct ReadableStreamGetReaderOptions {
pub:
	mode ?ReadableStreamReaderMode
}

pub struct ReadableStreamReader {
pub:
	kind           ReaderKind
	default_reader &ReadableStreamDefaultReader = unsafe { nil }
	byob_reader    &ReadableStreamBYOBReader    = unsafe { nil }
}

pub enum UnderlyingSourceType {
	default_source
	bytes
}

enum ReadableOwnerKind {
	regular
	transform
}

pub struct UnderlyingSource {
pub:
	type_                    UnderlyingSourceType
	start                    ?StartAlgorithm
	pull                     ?PullAlgorithm
	cancel                   ?CancelAlgorithm
	auto_allocate_chunk_size ?u64
}

@[heap]
pub struct ReadableStream {
mut:
	state_              ReadableStreamState
	stored_error_       string
	disturbed_          bool
	reader_kind_        ReaderKind
	queue_              QueueWithSizes
	high_water_mark_    f64
	size_algorithm_     SizeAlgorithm = default_size_algorithm
	pull_algorithm_     ?PullAlgorithm
	cancel_algorithm_   ?CancelAlgorithm
	close_requested_    bool
	pulling_            bool
	pull_again_         bool
	started_            bool
	byte_stream_        bool
	auto_allocate_size_ ?u64
	default_controller_ &ReadableStreamDefaultController = unsafe { nil }
	byte_controller_    &ReadableByteStreamController    = unsafe { nil }
	default_reader_     &ReadableStreamDefaultReader     = unsafe { nil }
	byob_reader_        &ReadableStreamBYOBReader        = unsafe { nil }
	pending_reads_      []&ReadPromise
	pending_byob_       &BYOBReadPromise = unsafe { nil }
	pending_byob_size_  int
	pending_byob_min_   int
	byob_buffer_        []u8
	byob_request_       &ReadableStreamBYOBRequest = unsafe { nil }
	auto_allocate_read_ bool
	tee_branches_       []&ReadableStream
	tee_source_         &ReadableStream = unsafe { nil }
	tee_branch_index_   int
	tee_cancel_reason_  Value
	tee_cancel_promise_ &VoidPromise = unsafe { nil }
	tee_cancelled_      bool
	pipe_destination_   &WritableStream = unsafe { nil }
	pipe_promise_       &VoidPromise    = unsafe { nil }
	pipe_options_       StreamPipeOptions
	transfer_target_    &ReadableStream = unsafe { nil }
	owner_kind_         ReadableOwnerKind
	owner_              voidptr
}

pub fn ReadableStream.construct_impl(source UnderlyingSource, strategy QueuingStrategy) !&ReadableStream {
	if source.type_ == .bytes && strategy.size != none {
		return error('RangeError: A byte stream cannot have a size function')
	}
	default_hwm := if source.type_ == .bytes { 0.0 } else { 1.0 }
	high_water_mark := extract_high_water_mark(strategy, default_hwm)!
	mut stream := &ReadableStream{
		high_water_mark_:  high_water_mark
		size_algorithm_:   extract_size_algorithm(strategy)
		pull_algorithm_:   source.pull
		cancel_algorithm_: source.cancel
		byte_stream_:      source.type_ == .bytes
	}
	if source.type_ == .bytes {
		if size := source.auto_allocate_chunk_size {
			if size == 0 {
				return error('TypeError: autoAllocateChunkSize must be greater than zero')
			}
			stream.auto_allocate_size_ = size
		}
		stream.byte_controller_ = &ReadableByteStreamController{
			stream_: stream
		}
	} else {
		stream.default_controller_ = &ReadableStreamDefaultController{
			stream_: stream
		}
	}
	if start := source.start {
		start() or {
			stream.error(err.msg())
			return stream
		}
	}
	stream.started_ = true
	stream.call_pull_if_needed()
	return stream
}

pub fn ReadableStream.from(values []Value) !&ReadableStream {
	mut stream := ReadableStream.construct_impl(UnderlyingSource{}, QueuingStrategy{})!
	mut controller := stream.default_controller_
	for value in values {
		controller.enqueue(value)!
	}
	controller.close()!
	return stream
}

pub fn (stream &ReadableStream) state() ReadableStreamState {
	return stream.state_
}

pub fn (stream &ReadableStream) stored_error() string {
	return stream.stored_error_
}

pub fn (stream &ReadableStream) locked() bool {
	return stream.reader_kind_ != .none
}

pub fn (stream &ReadableStream) disturbed() bool {
	return stream.disturbed_
}

pub fn (stream &ReadableStream) is_byte_stream() bool {
	return stream.byte_stream_
}

pub fn (stream &ReadableStream) queue_total_size() f64 {
	return stream.queue_.total_size()
}

pub fn (stream &ReadableStream) queued_chunks() int {
	return stream.queue_.len()
}

pub fn (stream &ReadableStream) desired_size() ?f64 {
	return match stream.state_ {
		.errored { none }
		.closed { 0.0 }
		.readable { stream.high_water_mark_ - stream.queue_.total_size() }
	}
}

pub fn (stream &ReadableStream) default_controller() !&ReadableStreamDefaultController {
	if stream.byte_stream_ {
		return error('TypeError: Byte streams do not have a default controller')
	}
	return stream.default_controller_
}

pub fn (stream &ReadableStream) byte_controller() !&ReadableByteStreamController {
	if !stream.byte_stream_ {
		return error('TypeError: This is not a byte stream')
	}
	return stream.byte_controller_
}

pub fn (mut stream ReadableStream) get_reader(options ReadableStreamGetReaderOptions) !ReadableStreamReader {
	if _ := options.mode {
		return ReadableStreamReader{
			kind:        .byob
			byob_reader: stream.get_byob_reader()!
		}
	}
	return ReadableStreamReader{
		kind:           .default_reader
		default_reader: stream.get_default_reader()!
	}
}

pub fn (mut stream ReadableStream) enqueue(value Value) ! {
	if stream.byte_stream_ {
		if value.kind != .bytes {
			return error('TypeError: A readable byte stream requires a byte chunk')
		}
		mut controller := stream.byte_controller_
		controller.enqueue(value.bytes_)!
		return
	}
	mut controller := stream.default_controller_
	controller.enqueue(value)!
}

pub fn (mut stream ReadableStream) pull_from_bytes(bytes []u8) ! {
	if !stream.byte_stream_ {
		return error('TypeError: pull_from_bytes requires byte reading support')
	}
	mut controller := stream.byte_controller_
	controller.enqueue(bytes)!
}

pub fn (mut stream ReadableStream) set_up_with_byte_reading_support(high_water_mark f64) ! {
	if stream.locked() || stream.disturbed_ || !stream.queue_.is_empty() {
		return error('TypeError: Cannot replace an active ReadableStream controller')
	}
	if high_water_mark < 0 {
		return error('RangeError: highWaterMark must be non-negative')
	}
	stream.byte_stream_ = true
	stream.high_water_mark_ = high_water_mark
	stream.default_controller_ = unsafe { nil }
	stream.byte_controller_ = &ReadableByteStreamController{
		stream_: &stream
	}
}

pub fn (mut stream ReadableStream) current_byob_request_view() ?[]u8 {
	if !stream.byte_stream_ {
		return none
	}
	mut controller := stream.byte_controller_
	request := controller.byob_request() or { return none }
	return request.view()
}

pub fn (mut stream ReadableStream) piped_through(mut transform TransformStream, prevent_close bool, prevent_abort bool, prevent_cancel bool, signal ?&AbortSignal) &ReadableStream {
	mut writable := transform.writable_
	stream.pipe_to(mut writable, StreamPipeOptions{
		prevent_close:  prevent_close
		prevent_abort:  prevent_abort
		prevent_cancel: prevent_cancel
		signal:         signal
	})
	return transform.readable_
}

fn (mut stream ReadableStream) call_pull_if_needed() {
	if !stream.started_ || stream.state_ != .readable || stream.close_requested_ {
		return
	}
	desired := stream.desired_size() or { return }
	if desired <= 0 && stream.pending_reads_.len == 0 && isnil(stream.pending_byob_) {
		return
	}
	if stream.pulling_ {
		stream.pull_again_ = true
		return
	}
	algorithm := stream.pull_algorithm_ or { return }
	stream.pulling_ = true
	algorithm() or { stream.error(err.msg()) }
	stream.pulling_ = false
	if stream.pull_again_ {
		stream.pull_again_ = false
		stream.call_pull_if_needed()
	}
}

fn (mut stream ReadableStream) enqueue_internal(value Value, size f64) ! {
	if stream.state_ != .readable || stream.close_requested_ {
		return error('TypeError: The readable stream cannot be enqueued into')
	}
	if stream.pending_reads_.len > 0 {
		mut promise := stream.pending_reads_[0]
		stream.pending_reads_.delete(0)
		promise.resolve(value, false)
	} else {
		stream.queue_.enqueue_value_with_size(value, size)!
	}
	stream.call_pull_if_needed()
}

fn (mut stream ReadableStream) close_internal() {
	if stream.state_ != .readable {
		return
	}
	stream.state_ = .closed
	for mut promise in stream.pending_reads_ {
		promise.resolve(undefined_value(), true)
	}
	stream.pending_reads_.clear()
	if !isnil(stream.pending_byob_) {
		mut byob := stream.pending_byob_
		byob.resolve([], true)
		stream.pending_byob_ = unsafe { nil }
	}
	stream.invalidate_byob_request()
	if !isnil(stream.default_reader_) {
		mut closed := stream.default_reader_.closed_
		closed.resolve()
	}
	if !isnil(stream.byob_reader_) {
		mut closed := stream.byob_reader_.closed_
		closed.resolve()
	}
	for mut branch in stream.tee_branches_ {
		branch.close_requested_ = true
		if branch.queue_.is_empty() {
			branch.close_internal()
		}
		pump_readable_pipe(mut branch)
	}
	all_tee_branches_cancelled := stream.tee_branches_.len > 0
		&& stream.tee_branches_.all(it.tee_cancelled_)
	if !all_tee_branches_cancelled {
		for mut branch in stream.tee_branches_ {
			if !isnil(branch.tee_cancel_promise_) && branch.tee_cancel_promise_.state() == .pending {
				mut cancel_promise := branch.tee_cancel_promise_
				cancel_promise.resolve()
			}
		}
	}
	if !isnil(stream.transfer_target_) {
		mut target := stream.transfer_target_
		target.close_requested_ = true
		if target.queue_.is_empty() {
			target.close_internal()
		}
		pump_readable_pipe(mut target)
	}
}

pub fn (mut stream ReadableStream) close() {
	if stream.state_ == .readable {
		stream.close_requested_ = true
		if stream.queue_.is_empty() {
			stream.close_internal()
		}
	}
	pump_readable_pipe(mut stream)
}

pub fn (mut stream ReadableStream) error(reason string) {
	if stream.state_ != .readable {
		return
	}
	stream.state_ = .errored
	stream.stored_error_ = reason
	stream.queue_.reset()
	for mut promise in stream.pending_reads_ {
		promise.reject(reason)
	}
	stream.pending_reads_.clear()
	if !isnil(stream.pending_byob_) {
		mut byob := stream.pending_byob_
		byob.reject(reason)
		stream.pending_byob_ = unsafe { nil }
	}
	stream.invalidate_byob_request()
	if !isnil(stream.default_reader_) {
		mut closed := stream.default_reader_.closed_
		closed.reject(reason)
	}
	if !isnil(stream.byob_reader_) {
		mut closed := stream.byob_reader_.closed_
		closed.reject(reason)
	}
	for mut branch in stream.tee_branches_ {
		branch.error(reason)
		if !isnil(branch.tee_cancel_promise_) && branch.tee_cancel_promise_.state() == .pending {
			mut cancel_promise := branch.tee_cancel_promise_
			cancel_promise.reject(reason)
		}
	}
	if !isnil(stream.transfer_target_) {
		mut target := stream.transfer_target_
		target.error(reason)
	}
	pump_readable_pipe(mut stream)
}

fn (mut stream ReadableStream) cancel_internal(reason Value) &VoidPromise {
	stream.disturbed_ = true
	if stream.state_ == .closed {
		return VoidPromise.fulfilled()
	}
	if stream.state_ == .errored {
		return VoidPromise.rejected(stream.stored_error_)
	}
	if !isnil(stream.tee_source_) {
		return cancel_tee_branch(mut stream, reason)
	}
	stream.queue_.reset()
	stream.close_internal()
	if stream.owner_kind_ == .transform {
		mut transform := unsafe { &TransformStream(stream.owner_) }
		return transform.cancel_readable(reason)
	}
	if cancel := stream.cancel_algorithm_ {
		cancel(reason) or { return VoidPromise.rejected(err.msg()) }
	}
	return VoidPromise.fulfilled()
}

pub fn (mut stream ReadableStream) cancel(reason Value) &VoidPromise {
	if stream.locked() {
		return VoidPromise.rejected('TypeError: Cannot cancel a locked ReadableStream')
	}
	return stream.cancel_internal(reason)
}

fn (mut stream ReadableStream) read_internal() &ReadPromise {
	stream.disturbed_ = true
	if !stream.queue_.is_empty() {
		value := stream.queue_.dequeue_value() or { return ReadPromise.rejected(err.msg()) }
		if stream.close_requested_ && stream.queue_.is_empty() {
			stream.close_internal()
		} else {
			stream.call_pull_if_needed()
		}
		return ReadPromise.fulfilled(value, false)
	}
	if stream.state_ == .closed {
		return ReadPromise.fulfilled(undefined_value(), true)
	}
	if stream.state_ == .errored {
		return ReadPromise.rejected(stream.stored_error_)
	}
	promise := ReadPromise.pending()
	stream.pending_reads_ << promise
	if stream.byte_stream_ {
		if size := stream.auto_allocate_size_ {
			stream.pending_byob_size_ = int(size)
			stream.pending_byob_min_ = 1
			stream.byob_buffer_.clear()
			stream.auto_allocate_read_ = true
		}
	}
	stream.call_pull_if_needed()
	return promise
}

pub fn (mut stream ReadableStream) get_default_reader() !&ReadableStreamDefaultReader {
	if stream.locked() {
		return error('TypeError: ReadableStream is already locked')
	}
	mut closed := VoidPromise.pending()
	if stream.state_ == .closed {
		closed.resolve()
	} else if stream.state_ == .errored {
		closed.reject(stream.stored_error_)
	}
	reader := &ReadableStreamDefaultReader{
		stream_: &stream
		closed_: closed
	}
	stream.reader_kind_ = .default_reader
	stream.default_reader_ = reader
	return reader
}

@[heap]
pub struct ReadableStreamDefaultController {
mut:
	stream_ &ReadableStream = unsafe { nil }
}

pub fn (controller &ReadableStreamDefaultController) desired_size() ?f64 {
	return controller.stream_.desired_size()
}

pub fn (mut controller ReadableStreamDefaultController) enqueue(value Value) ! {
	mut stream := controller.stream_
	if stream.state_ != .readable || stream.close_requested_ {
		return error('TypeError: The controller cannot enqueue')
	}
	if stream.tee_branches_.len > 0 {
		for mut branch in stream.tee_branches_ {
			if branch.state_ == .readable {
				mut branch_controller := branch.default_controller_
				branch_controller.enqueue(structured_clone(value))!
			}
		}
		stream.disturbed_ = true
		return
	}
	if !isnil(stream.transfer_target_) {
		mut target := stream.transfer_target_
		mut target_controller := target.default_controller_
		target_controller.enqueue(structured_clone(value))!
		stream.disturbed_ = true
		return
	}
	if stream.pending_reads_.len > 0 {
		stream.enqueue_internal(value, 0)!
		pump_readable_pipe(mut stream)
		return
	}
	size := stream.size_algorithm_(value) or {
		stream.error(err.msg())
		return err
	}
	stream.enqueue_internal(value, size)!
	pump_readable_pipe(mut stream)
}

pub fn (mut controller ReadableStreamDefaultController) close() ! {
	mut stream := controller.stream_
	if stream.state_ != .readable || stream.close_requested_ {
		return error('TypeError: The controller cannot close this stream')
	}
	stream.close()
	pump_readable_pipe(mut stream)
}

pub fn (mut controller ReadableStreamDefaultController) error(reason string) {
	mut stream := controller.stream_
	stream.error(reason)
	pump_readable_pipe(mut stream)
}

@[heap]
pub struct ReadableStreamDefaultReader {
mut:
	stream_   &ReadableStream = unsafe { nil }
	closed_   &VoidPromise    = unsafe { nil }
	released_ bool
}

pub fn ReadableStreamDefaultReader.construct_impl(mut stream ReadableStream) !&ReadableStreamDefaultReader {
	return stream.get_default_reader()
}

pub fn (reader &ReadableStreamDefaultReader) closed() &VoidPromise {
	return reader.closed_
}

pub fn (mut reader ReadableStreamDefaultReader) read() &ReadPromise {
	if reader.released_ || isnil(reader.stream_) {
		return ReadPromise.rejected('TypeError: Reader has no associated stream')
	}
	mut stream := reader.stream_
	return stream.read_internal()
}

pub fn (mut reader ReadableStreamDefaultReader) cancel(reason Value) &VoidPromise {
	if reader.released_ || isnil(reader.stream_) {
		return VoidPromise.rejected('TypeError: Reader has no associated stream')
	}
	mut stream := reader.stream_
	return stream.cancel_internal(reason)
}

pub fn (mut reader ReadableStreamDefaultReader) release_lock() ! {
	if reader.released_ {
		return
	}
	if isnil(reader.stream_) {
		return
	}
	mut stream := reader.stream_
	for mut promise in stream.pending_reads_ {
		promise.reject('TypeError: Reader has been released')
	}
	stream.pending_reads_.clear()
	stream.reader_kind_ = .none
	stream.default_reader_ = unsafe { nil }
	reader.released_ = true
	reader.stream_ = unsafe { nil }
	if stream.state_ == .readable {
		mut closed := reader.closed_
		closed.reject('TypeError: Reader has been released')
	} else {
		reader.closed_ = VoidPromise.rejected('TypeError: Reader has been released')
	}
}

pub fn (mut reader ReadableStreamDefaultReader) read_all_bytes() ![]u8 {
	mut bytes := []u8{}
	for {
		promise := reader.read()
		if promise.state() == .pending {
			return error('TypeError: Stream did not synchronously produce a chunk')
		}
		if promise.state() == .rejected {
			return error(promise.reason())
		}
		result := promise.result()
		if result.done {
			return bytes
		}
		if result.value.kind != .bytes {
			return error('TypeError: A non-byte chunk was read')
		}
		bytes << result.value.bytes_
	}
	return bytes
}

pub struct ReadableStreamIteratorOptions {
pub:
	prevent_cancel bool
}

@[heap]
pub struct ReadableStreamAsyncIterator {
mut:
	reader_         &ReadableStreamDefaultReader = unsafe { nil }
	prevent_cancel_ bool
	finished_       bool
}

pub fn ReadableStreamAsyncIterator.create(mut stream ReadableStream, options ReadableStreamIteratorOptions) !&ReadableStreamAsyncIterator {
	reader := stream.get_default_reader()!
	return &ReadableStreamAsyncIterator{
		reader_:         reader
		prevent_cancel_: options.prevent_cancel
	}
}

pub fn (mut iterator ReadableStreamAsyncIterator) next_iteration_result() &ReadPromise {
	if iterator.finished_ {
		return ReadPromise.fulfilled(undefined_value(), true)
	}
	promise := iterator.reader_.read()
	if promise.state() == .fulfilled && promise.result().done {
		iterator.finished_ = true
		iterator.reader_.release_lock() or {}
	}
	return promise
}

pub fn (mut iterator ReadableStreamAsyncIterator) iterator_return(reason Value) &VoidPromise {
	iterator.finished_ = true
	mut result := VoidPromise.fulfilled()
	if !iterator.prevent_cancel_ {
		result = iterator.reader_.cancel(reason)
	}
	iterator.reader_.release_lock() or {}
	return result
}
