// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ReadableStream, its generic/default readers and controller,
// ReadableStreamAsyncIterator, and the corresponding abstract operations.
module streams

import webidl

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
	message_port
	iterable
}

pub struct UnderlyingSource {
pub:
	type_                    UnderlyingSourceType
	start                    ?StartAlgorithm
	pull                     ?PullAlgorithm
	cancel                   ?CancelAlgorithm
	start_promise            ?PromiseStartAlgorithm
	pull_promise             ?PromisePullAlgorithm
	cancel_promise           ?PromiseCancelAlgorithm
	underlying_source_value  webidl.Value
	start_callback           ?webidl.CallbackType
	pull_callback            ?webidl.CallbackType
	cancel_callback          ?webidl.CallbackType
	auto_allocate_chunk_size ?u64
}

@[heap]
pub struct ReadableStream {
mut:
	realm_                    StreamRealm
	result_realm_             ?StreamRealm
	state_                    ReadableStreamState
	stored_error_             string
	stored_error_value_       ?webidl.Value
	disturbed_                bool
	reader_kind_              ReaderKind
	queue_                    QueueWithSizes
	high_water_mark_          f64
	size_algorithm_           SizeAlgorithm = default_size_algorithm
	size_value_algorithm_     ?ValueSizeAlgorithm
	pull_algorithm_           ?PullAlgorithm
	cancel_algorithm_         ?CancelAlgorithm
	promise_pull_algorithm_   ?PromisePullAlgorithm
	promise_cancel_algorithm_ ?PromiseCancelAlgorithm
	close_requested_          bool
	pulling_                  bool
	pull_again_               bool
	started_                  bool
	byte_stream_              bool
	auto_allocate_size_       ?u64
	default_controller_       &ReadableStreamDefaultController = unsafe { nil }
	byte_controller_          &ReadableByteStreamController    = unsafe { nil }
	default_reader_           &ReadableStreamDefaultReader     = unsafe { nil }
	byob_reader_              &ReadableStreamBYOBReader        = unsafe { nil }
	pending_reads_            ReadPromiseList
	byob_request_             &ReadableStreamBYOBRequest = unsafe { nil }
	tee_branches_             []&ReadableStream
	tee_source_               &ReadableStream = unsafe { nil }
	tee_branch_index_         int
	tee_cancel_reason_        Value
	tee_cancel_promise_       &VoidPromise = unsafe { nil }
	tee_cancelled_            bool
	tee_read_request_         &ReadPromise     = unsafe { nil }
	tee_byob_request_         &BYOBReadPromise = unsafe { nil }
	tee_byob_branch_          int
	tee_reading_              bool
	tee_delivery_queued_      bool
	tee_read_again_           bool
	tee_read_again_1_         bool
	tee_read_again_2_         bool
	tee_clone_branch2_        bool
	pipe_destination_         &WritableStream       = unsafe { nil }
	pipe_promise_             &VoidPromise          = unsafe { nil }
	pipe_operation_           &ReadableStreamPipeTo = unsafe { nil }
	pipe_read_request_        &ReadPromise          = unsafe { nil }
	pipe_pumping_             bool
	pipe_options_             StreamPipeOptions
	owner_kind_               ReadableOwnerKind
	owner_                    voidptr
	message_port_             &MessagePort = unsafe { nil }
	from_values_              []Value
	from_index_               int
}

pub fn ReadableStream.construct_impl(source UnderlyingSource, strategy QueuingStrategy) !&ReadableStream {
	return ReadableStream.create(StreamRealm{}, source, strategy)
}

pub fn ReadableStream.create_for_constructor(realm StreamRealm, source UnderlyingSource, strategy QueuingStrategy) !&ReadableStream {
	return ReadableStream.create(realm, source, strategy)
}

pub fn ReadableStream.create(realm StreamRealm, source UnderlyingSource, strategy QueuingStrategy) !&ReadableStream {
	if source.type_ == .bytes && (strategy.size != none || strategy.size_value != none) {
		return error('RangeError: A byte stream cannot have a size function')
	}
	default_hwm := if source.type_ == .bytes { 0.0 } else { 1.0 }
	high_water_mark := extract_high_water_mark(strategy, default_hwm)!
	mut stream := &ReadableStream{
		realm_: realm
		size_value_algorithm_: strategy.size_value
	}
	initialize_readable_stream(mut stream)
	if source.type_ == .bytes {
		set_up_readable_byte_stream_controller_from_underlying_source(mut stream, source, high_water_mark)!
	} else {
		set_up_readable_stream_default_controller_from_underlying_source(mut stream, source, high_water_mark, extract_size_algorithm(strategy))!
	}
	return stream
}

pub fn ReadableStream.from(values []Value) !&ReadableStream {
	return ReadableStream.from_in_realm(StreamRealm{}, values)
}

pub fn ReadableStream.from_in_realm(realm StreamRealm, values []Value) !&ReadableStream {
	mut stream := ReadableStream.create(realm, UnderlyingSource{}, QueuingStrategy{
		high_water_mark: 0
	})!
	stream.owner_kind_ = .iterable
	// ReadableStreamFromIterable retains the iterator record and consumes it on
	// demand. The typed V boundary receives an array, so retain its backing
	// storage instead of eagerly cloning every value.
	stream.from_values_ = unsafe { values }
	return stream
}

pub fn (stream &ReadableStream) realm() StreamRealm {
	return stream.realm_
}

pub fn (mut stream ReadableStream) set_realm(realm StreamRealm) {
	stream.realm_ = realm
}

pub fn (stream &ReadableStream) result_realm() ?StreamRealm {
	return stream.result_realm_
}

pub fn (mut stream ReadableStream) set_result_realm(realm StreamRealm) {
	stream.result_realm_ = realm
}

fn pump_readable_from_iterable(mut stream ReadableStream) {
	if stream.owner_kind_ != .iterable || stream.state_ != .readable {
		return
	}
	if stream.pulling_ {
		stream.pull_again_ = true
		return
	}
	stream.pulling_ = true
	if stream.from_index_ >= stream.from_values_.len {
		mut controller := stream.default_controller_
		controller.close() or { stream.error(err.msg()) }
		stream.from_values_.clear()
	} else {
		value := stream.from_values_[stream.from_index_]
		stream.from_index_++
		mut controller := stream.default_controller_
		controller.enqueue(value) or { stream.error(err.msg()) }
	}
	stream.pulling_ = false
	if stream.pull_again_ {
		stream.pull_again_ = false
		pump_readable_from_iterable(mut stream)
	}
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
	if stream.byte_stream_ && !isnil(stream.byte_controller_) {
		return stream.byte_controller_.queue_total_size_
	}
	return stream.queue_.total_size()
}

pub fn (stream &ReadableStream) queued_chunks() int {
	if stream.byte_stream_ && !isnil(stream.byte_controller_) {
		return stream.byte_controller_.queue_length_
	}
	return stream.queue_.len()
}

pub fn (stream &ReadableStream) desired_size() ?f64 {
	return match stream.state_ {
		.errored { none }
		.closed { 0.0 }
		.readable { stream.high_water_mark_ - stream.queue_total_size() }
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
		assert value.kind == .bytes, 'Source VERIFY: internal byte stream enqueue requires an ArrayBufferView'
		mut controller := stream.byte_controller_
		// ReadableStream.cpp invokes the abstract operation directly. Public
		// controller enqueue has an additional zero-byte rejection gate.
		readable_byte_stream_controller_enqueue(mut controller, value)!
		return
	}
	mut controller := stream.default_controller_
	readable_stream_default_controller_enqueue(mut controller, value) or {
		panic('Source MUST: internal default stream enqueue failed: ${err.msg()}')
	}
}

pub fn (mut stream ReadableStream) pull_from_bytes(bytes []u8) ! {
	if !stream.byte_stream_ {
		return error('TypeError: pull_from_bytes requires byte reading support')
	}
	mut pull_size := bytes.len
	if view := stream.current_byob_request_view() {
		if view.len < pull_size {
			pull_size = view.len
		}
	}
	pulled := unsafe { bytes[..pull_size] }
	mut controller := stream.byte_controller_
	if !isnil(stream.byob_request_) {
		mut request := stream.byob_request_
		request.write_view(pulled)!
		readable_byte_stream_controller_respond(mut controller, u64(pull_size))!
	} else {
		controller.enqueue(pulled)!
	}
}

pub fn (mut stream ReadableStream) set_up_with_byte_reading_support(high_water_mark f64) ! {
	stream.set_up_with_byte_reading_support_in_realm(stream.realm_, none, none, high_water_mark)
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

pub fn (mut stream ReadableStream) values(options ReadableStreamIteratorOptions) !&ReadableStreamAsyncIterator {
	return ReadableStreamAsyncIterator.create(mut stream, options)
}

fn (mut stream ReadableStream) call_pull_if_needed() {
	if !stream.started_ || stream.state_ != .readable || stream.close_requested_ {
		return
	}
	desired := stream.desired_size() or { return }
	byob_reads_pending := !isnil(stream.byob_reader_) && stream.byob_reader_.read_into_requests_.len > 0
	if desired <= 0 && stream.pending_reads_.len == 0 && !byob_reads_pending {
		return
	}
	if !isnil(stream.tee_source_) {
		pump_readable_tee_branch(mut stream)
		return
	}
	if stream.owner_kind_ == .message_port && !isnil(stream.message_port_) {
		mut port := stream.message_port_
		pack_and_post_message(mut port, 'pull', undefined_value()) or {
			stream.error(err.msg())
		}
		return
	}
	if stream.owner_kind_ == .iterable {
		pump_readable_from_iterable(mut stream)
		return
	}

	if stream.pulling_ {
		stream.pull_again_ = true
		return
	}
	if stream.pull_algorithm_ == none && stream.promise_pull_algorithm_ == none { return }
	stream.pulling_ = true
	mut pull_promise := stream.invoke_pull_algorithm()
	webidl.react_to_promise(mut pull_promise, fn [mut stream] (_ webidl.Value) !webidl.Value {
		stream.pulling_ = false
		if stream.pull_again_ {
			stream.pull_again_ = false
			stream.call_pull_if_needed()
		}
		return webidl.undefined_value()
	}, fn [mut stream] (reason webidl.Value) !webidl.Value {
		stream.error_value(reason)
		return webidl.undefined_value()
	})
}

fn (mut stream ReadableStream) enqueue_internal(value Value, size f64) ! {
	if stream.state_ != .readable || stream.close_requested_ {
		return error('TypeError: The readable stream cannot be enqueued into')
	}
	if stream.pending_reads_.len > 0 {
		mut promise := stream.pending_reads_.shift()!
		promise.on_chunk(value)
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
	for mut promise in stream.pending_reads_.values() {
		promise.on_close()
	}
	stream.pending_reads_.clear()
	if !isnil(stream.default_reader_) {
		mut closed := stream.default_reader_.closed_
		closed.resolve()
	}
	if !isnil(stream.byob_reader_) {
		mut closed := stream.byob_reader_.closed_
		closed.resolve()
	}
	pump_readable_tee_source(mut stream)
}

pub fn (mut stream ReadableStream) close() {
	if stream.byte_stream_ && !isnil(stream.byte_controller_) {
		mut controller := stream.byte_controller_
		// A partial BYOB element errors the stream. Do not continue closing it.
		readable_byte_stream_controller_close(mut controller) or { return }
		if controller.pending_pull_intos_.len > 0 {
			readable_byte_stream_controller_respond(mut controller, 0) or {}
		}
	} else if !isnil(stream.default_controller_) {
		mut controller := stream.default_controller_
		readable_stream_default_controller_close(mut controller)
	} else if stream.state_ == .readable {
		stream.close_internal()
	}
	pump_readable_pipe(mut stream)
}

fn (mut stream ReadableStream) error_internal(reason string) {
	stream.error_internal_value(webidl.string_value(reason), reason)
}

fn (mut stream ReadableStream) error_internal_value(reason webidl.Value, description string) {
	if stream.state_ != .readable {
		return
	}
	stream.state_ = .errored
	stream.stored_error_ = description
	stream.stored_error_value_ = reason
	for mut promise in stream.pending_reads_.values() {
		promise.on_error(reason)
	}
	stream.pending_reads_.clear()
	if !isnil(stream.default_reader_) {
		mut closed := stream.default_reader_.closed_
		closed.reject_value(reason)
	}
	if !isnil(stream.byob_reader_) {
		mut closed := stream.byob_reader_.closed_
		closed.reject_value(reason)
		for mut request in stream.byob_reader_.read_into_requests_ {
			request.reject_value(reason)
		}
		stream.byob_reader_.read_into_requests_.clear()
	}
	pump_readable_tee_source(mut stream)
	pump_readable_pipe(mut stream)
}

pub fn (mut stream ReadableStream) error(reason string) {
	if stream.state_ != .readable {
		return
	}
	if stream.byte_stream_ && !isnil(stream.byte_controller_) {
		mut controller := stream.byte_controller_
		readable_byte_stream_controller_error(mut controller, string_value(reason))
	} else if !isnil(stream.default_controller_) {
		mut controller := stream.default_controller_
		readable_stream_default_controller_error(mut controller, string_value(reason))
	} else {
		stream.error_internal(reason)
	}
}

fn (mut stream ReadableStream) cancel_internal(reason Value) &VoidPromise {
	stream.disturbed_ = true
	if stream.state_ == .closed {
		return VoidPromise.fulfilled_in(stream.realm_)
	}
	if stream.state_ == .errored {
		return VoidPromise.rejected_value_in(stream.realm_, stream.stored_error_value())
	}
	if !isnil(stream.tee_source_) {
		mut cancel_result := cancel_tee_branch(mut stream, reason).as_webidl_promise()
		return void_promise_from_webidl(stream.realm_, mut cancel_result)
	}
	if stream.owner_kind_ == .iterable {
		stream.from_values_.clear()
	}
	stream.close_internal()
	if !isnil(stream.byob_reader_) {
		for mut request in stream.byob_reader_.read_into_requests_ {
			request.resolve([], true)
		}
		stream.byob_reader_.read_into_requests_.clear()
	}

	if stream.owner_kind_ == .message_port && !isnil(stream.message_port_) {
		mut port := stream.message_port_
		pack_and_post_message(mut port, 'error', reason) or {
			port.close()
			return VoidPromise.rejected_in(stream.realm_, err.msg())
		}
		port.close()
		return VoidPromise.fulfilled_in(stream.realm_)
	}
	if stream.byte_stream_ {
		mut controller := stream.byte_controller_
		return controller.cancel_steps(reason)
	}
	mut controller := stream.default_controller_
	return controller.cancel_steps(reason)
}

pub fn (mut stream ReadableStream) cancel(reason Value) &VoidPromise {
	if stream.locked() {
		return VoidPromise.rejected_in(stream.realm_, 'TypeError: Cannot cancel a locked ReadableStream')
	}
	return stream.cancel_internal(reason)
}

fn (mut stream ReadableStream) read_internal() &ReadPromise {
	return stream.read_internal_in(stream.realm_)
}

fn (mut stream ReadableStream) read_internal_in(promise_realm StreamRealm) &ReadPromise {
	stream.disturbed_ = true
	if stream.state_ == .closed {
		return ReadPromise.fulfilled_in(promise_realm, stream.result_realm_, undefined_value(), true)
	}
	if stream.state_ == .errored {
		return ReadPromise.rejected_value_in(promise_realm, stream.result_realm_, stream.stored_error_value())
	}
	if stream.byte_stream_ {
		mut controller := stream.byte_controller_
		return controller.pull_steps_in(promise_realm)
	}
	mut controller := stream.default_controller_
	return controller.pull_steps_in(promise_realm)
}

pub fn (mut stream ReadableStream) get_default_reader() !&ReadableStreamDefaultReader {
	return ReadableStreamDefaultReader.create(stream.realm_, mut stream)
}

pub fn ReadableStreamDefaultReader.create(realm StreamRealm, mut stream ReadableStream) !&ReadableStreamDefaultReader {
	if stream.locked() {
		return error('TypeError: ReadableStream is already locked')
	}
	mut closed := VoidPromise.pending_in(realm)
	if stream.state_ == .closed {
		closed.resolve()
	} else if stream.state_ == .errored {
		closed.reject_value(stream.stored_error_value())
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
	if !readable_stream_default_controller_can_close_or_enqueue(controller) {
		return error('TypeError: The controller cannot enqueue')
	}
	readable_stream_default_controller_enqueue(mut controller, value)!
}

pub fn (mut controller ReadableStreamDefaultController) close() ! {
	if !readable_stream_default_controller_can_close_or_enqueue(controller) {
		return error('TypeError: The controller cannot close this stream')
	}
	readable_stream_default_controller_close(mut controller)
}

pub fn (mut controller ReadableStreamDefaultController) error(reason string) {
	readable_stream_default_controller_error(mut controller, string_value(reason))
}

@[heap]
pub struct ReadableStreamDefaultReader {
mut:
	stream_            &ReadableStream = unsafe { nil }
	closed_            &VoidPromise    = unsafe { nil }
	released_          bool
	pipe_to_operation_ &ReadableStreamPipeTo = unsafe { nil }
}

pub fn ReadableStreamDefaultReader.construct_impl(mut stream ReadableStream) !&ReadableStreamDefaultReader {
	return ReadableStreamDefaultReader.create(stream.realm_, mut stream)
}

pub fn (reader &ReadableStreamDefaultReader) closed() &VoidPromise {
	return reader.closed_
}

pub fn (reader &ReadableStreamDefaultReader) closed_promise_realm() StreamRealm {
	mixin := ReadableStreamGenericReaderMixin.from_promise(reader.closed_)
	return mixin.closed_promise_realm()
}

pub fn (mut reader ReadableStreamDefaultReader) read() &ReadPromise {
	if reader.released_ || isnil(reader.stream_) {
		return ReadPromise.rejected_in(reader.closed_promise_realm(), none, 'TypeError: Reader has no associated stream')
	}
	mut stream := reader.stream_
	mut promise := ReadPromise.pending_in(reader.closed_promise_realm(), stream.result_realm_)
	readable_stream_default_reader_read_request(mut reader, mut promise)
	return promise
}

pub fn (mut reader ReadableStreamDefaultReader) cancel(reason Value) &VoidPromise {
	if reader.released_ || isnil(reader.stream_) {
		return VoidPromise.rejected_in(reader.closed_promise_realm(), 'TypeError: Reader has no associated stream')
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
	readable_stream_default_reader_generic_release(mut reader)
	reason := webidl.simple_exception_value(webidl.SimpleException{type_: .type_error, message: 'Reader has been released'})
	for mut promise in stream.pending_reads_.values() {
		promise.on_error(reason)
	}
	stream.pending_reads_.clear()
}

fn readable_stream_default_reader_generic_release(mut reader ReadableStreamDefaultReader) {
	mut stream := reader.stream_
	if stream.state_ == .readable {
		mut closed := reader.closed_
		closed.reject('TypeError: Reader has been released')
	} else {
		reader.closed_ = VoidPromise.rejected_in(reader.closed_promise_realm(), 'TypeError: Reader has been released')
	}
	if stream.byte_stream_ && !isnil(stream.byte_controller_) {
		mut controller := stream.byte_controller_
		controller.release_steps()
	} else if !isnil(stream.default_controller_) {
		mut controller := stream.default_controller_
		controller.release_steps()
	}
	stream.reader_kind_ = .none
	stream.default_reader_ = unsafe { nil }
	reader.released_ = true
	reader.stream_ = unsafe { nil }
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
	prototype_set_  bool
}

pub fn ReadableStreamAsyncIterator.create(mut stream ReadableStream, options ReadableStreamIteratorOptions) !&ReadableStreamAsyncIterator {
	reader := stream.get_default_reader()!
	mut iterator := &ReadableStreamAsyncIterator{
		reader_:         reader
		prevent_cancel_: options.prevent_cancel
	}
	set_readable_stream_async_iterator_prototype(mut iterator)
	return iterator
}

pub fn set_readable_stream_async_iterator_prototype(mut iterator ReadableStreamAsyncIterator) {
	iterator.prototype_set_ = true
}

pub fn (iterator &ReadableStreamAsyncIterator) prototype_is_set() bool {
	return iterator.prototype_set_
}

pub fn (mut iterator ReadableStreamAsyncIterator) next_iteration_result() &ReadPromise {
	if iterator.finished_ {
		return ReadPromise.fulfilled_in(iterator.reader_.closed_promise_realm(), none, undefined_value(), true)
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
	mut result := VoidPromise.fulfilled_in(iterator.reader_.closed_promise_realm())
	if !iterator.prevent_cancel_ {
		result = iterator.reader_.cancel(reason)
	}
	iterator.reader_.release_lock() or {}
	return result
}
