// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ReadableByteStreamController, ReadableStreamBYOBReader,
// ReadableStreamBYOBRequest, pull-into descriptors, and byte controller ops.
module streams

pub enum PullIntoReaderType {
	default_reader
	byob
	none
}

pub struct PullIntoDescriptor {
pub mut:
	buffer             ArrayBuffer
	buffer_byte_length int
	byte_offset        int
	byte_length        int
	bytes_filled       int
	minimum_fill       int
	element_size       int = 1
	reader_type        PullIntoReaderType
}

// Streams stores pending pull-into descriptors in a SinglyLinkedList. Keeping
// that shape matters here: completing a BYOB request removes the head, so an
// array-backed queue would move every remaining descriptor on each response.
@[heap]
struct PendingPullIntoEntry {
mut:
	descriptor PullIntoDescriptor
	next_      &PendingPullIntoEntry = unsafe { nil }
}

struct PendingPullIntoList {
mut:
	head_ &PendingPullIntoEntry = unsafe { nil }
	tail_ &PendingPullIntoEntry = unsafe { nil }
pub mut:
	len int
}

fn (mut list PendingPullIntoList) append(descriptor PullIntoDescriptor) {
	entry := &PendingPullIntoEntry{
		descriptor: descriptor
	}
	if isnil(list.tail_) {
		list.head_ = entry
	} else {
		mut tail := list.tail_
		tail.next_ = entry
	}
	list.tail_ = entry
	list.len++
}

fn (list &PendingPullIntoList) first() !PullIntoDescriptor {
	if isnil(list.head_) {
		return error('InternalError: No pending pull-into descriptor')
	}
	return list.head_.descriptor
}

fn (mut list PendingPullIntoList) set_first(descriptor PullIntoDescriptor) ! {
	if isnil(list.head_) {
		return error('InternalError: No pending pull-into descriptor')
	}
	list.head_.descriptor = descriptor
}

fn (mut list PendingPullIntoList) shift() !PullIntoDescriptor {
	if isnil(list.head_) {
		return error('InternalError: No pending pull-into descriptor')
	}
	mut entry := list.head_
	list.head_ = entry.next_
	entry.next_ = unsafe { nil }
	if isnil(list.head_) {
		list.tail_ = unsafe { nil }
	}
	list.len--
	return entry.descriptor
}

fn (mut list PendingPullIntoList) clear() {
	list.head_ = unsafe { nil }
	list.tail_ = unsafe { nil }
	list.len = 0
}

fn (list &PendingPullIntoList) values() []PullIntoDescriptor {
	mut descriptors := []PullIntoDescriptor{cap: list.len}
	mut entry := list.head_
	for !isnil(entry) {
		descriptors << entry.descriptor
		entry = entry.next_
	}
	return descriptors
}

fn new_pull_into_descriptor(byte_length int, minimum_fill int, element_size int, reader_type PullIntoReaderType) PullIntoDescriptor {
	return PullIntoDescriptor{
		buffer: ArrayBuffer.from_bytes([]u8{len: byte_length})
		buffer_byte_length: byte_length
		byte_length: byte_length
		minimum_fill: minimum_fill
		element_size: element_size
		reader_type: reader_type
	}
}

fn new_pull_into_descriptor_for_view(view []u8, minimum_fill int, reader_type PullIntoReaderType) PullIntoDescriptor {
	return PullIntoDescriptor{
		buffer: ArrayBuffer{
			data_: unsafe { view }
		}
		buffer_byte_length: view.len
		byte_length: view.len
		minimum_fill: minimum_fill
		element_size: 1
		reader_type: reader_type
	}
}

fn pull_into_descriptor_bytes(descriptor &PullIntoDescriptor) []u8 {
	if descriptor.bytes_filled == 0 {
		return []u8{}
	}
	return unsafe {
		descriptor.buffer.data_[descriptor.byte_offset..descriptor.byte_offset + descriptor.bytes_filled]
	}
}

fn copy_into_pull_into_descriptor(mut descriptor PullIntoDescriptor, source []u8, count int) ! {
	if count < 0 || count > source.len || descriptor.bytes_filled + count > descriptor.byte_length {
		return error('RangeError: Bytes exceed the pull-into descriptor')
	}
	start := descriptor.byte_offset + descriptor.bytes_filled
	if start < 0 || start + count > descriptor.buffer.data_.len {
		return error('RangeError: Pull-into descriptor is out of bounds')
	}
	copy(mut descriptor.buffer.data_[start..start + count], source[..count])
}

// https://streams.spec.whatwg.org/#readable-byte-stream-queue-entry
@[heap]
pub struct ReadableByteStreamQueueEntry {
pub mut:
	buffer      ArrayBuffer
	byte_offset int
	byte_length int
mut:
	next_ &ReadableByteStreamQueueEntry = unsafe { nil }
}

@[heap]
pub struct ReadableByteStreamController {
mut:
	stream_             &ReadableStream = unsafe { nil }
	pending_pull_intos_ PendingPullIntoList
	queue_head_         &ReadableByteStreamQueueEntry = unsafe { nil }
	queue_tail_         &ReadableByteStreamQueueEntry = unsafe { nil }
	queue_total_size_   f64
	queue_length_       int
}

fn (controller &ReadableByteStreamController) byte_queue_is_empty() bool {
	return isnil(controller.queue_head_)
}

fn (mut controller ReadableByteStreamController) append_byte_queue_entry(buffer &ArrayBuffer, byte_offset int, byte_length int) {
	entry := &ReadableByteStreamQueueEntry{
		buffer: ArrayBuffer{
			data_: buffer.data_
			detached_: buffer.detached_
		}
		byte_offset: byte_offset
		byte_length: byte_length
	}
	if isnil(controller.queue_tail_) {
		controller.queue_head_ = entry
	} else {
		mut tail := controller.queue_tail_
		tail.next_ = entry
	}
	controller.queue_tail_ = entry
	controller.queue_total_size_ += f64(byte_length)
	controller.queue_length_++
}

fn (mut controller ReadableByteStreamController) take_first_byte_queue_entry() !&ReadableByteStreamQueueEntry {
	if isnil(controller.queue_head_) {
		return error('InternalError: Cannot dequeue an empty byte stream queue')
	}
	mut entry := controller.queue_head_
	controller.queue_head_ = entry.next_
	entry.next_ = unsafe { nil }
	if isnil(controller.queue_head_) {
		controller.queue_tail_ = unsafe { nil }
	}
	controller.queue_total_size_ -= f64(entry.byte_length)
	controller.queue_length_--
	return entry
}

fn (mut controller ReadableByteStreamController) reset_byte_queue() {
	controller.queue_head_ = unsafe { nil }
	controller.queue_tail_ = unsafe { nil }
	controller.queue_total_size_ = 0
	controller.queue_length_ = 0
}

fn (controller &ReadableByteStreamController) byte_queue_entries() []ReadableByteStreamQueueEntry {
	mut entries := []ReadableByteStreamQueueEntry{cap: controller.queue_length_}
	mut current := controller.queue_head_
	for !isnil(current) {
		entries << ReadableByteStreamQueueEntry{
			buffer: ArrayBuffer{
				data_: current.buffer.data_
				detached_: current.buffer.detached_
			}
			byte_offset: current.byte_offset
			byte_length: current.byte_length
		}
		current = current.next_
	}
	return entries
}

pub fn (controller &ReadableByteStreamController) desired_size() ?f64 {
	return readable_byte_stream_controller_get_desired_size(controller)
}

pub fn (mut controller ReadableByteStreamController) enqueue(chunk []u8) ! {
	// ReadableByteStreamController::enqueue, steps 1-4.
	if chunk.len == 0 {
		return error('TypeError: Cannot enqueue chunk with byte length of zero')
	}
	if controller.stream_.close_requested_ {
		return error('TypeError: Close is requested for controller')
	}
	if controller.stream_.state_ != .readable {
		return error('TypeError: Stream is not readable')
	}
	readable_byte_stream_controller_enqueue(mut controller, bytes_value(chunk))!
}

pub fn (mut controller ReadableByteStreamController) close() ! {
	// ReadableByteStreamController::close, steps 1-3.
	if controller.stream_.close_requested_ {
		return error('TypeError: Controller is already closed')
	}
	if controller.stream_.state_ != .readable {
		message := if controller.stream_.state_ == .closed {
			'Cannot close a closed stream'
		} else {
			'Cannot close an errored stream'
		}
		return error('TypeError: ${message}')
	}
	readable_byte_stream_controller_close(mut controller)!
}

pub fn (mut controller ReadableByteStreamController) error(reason string) {
	readable_byte_stream_controller_error(mut controller, string_value(reason))
}

pub fn (mut controller ReadableByteStreamController) byob_request() ?&ReadableStreamBYOBRequest {
	return readable_byte_stream_controller_get_byob_request(mut controller)
}

fn (mut stream ReadableStream) invalidate_byob_request() {
	if isnil(stream.byob_request_) {
		return
	}
	mut request := stream.byob_request_
	request.active_ = false
	request.controller_ = unsafe { nil }
	request.view_.clear()
	request.written_length_ = 0
	stream.byob_request_ = unsafe { nil }
}

fn (mut stream ReadableStream) byte_controller_pull_steps() &ReadPromise {
	mut controller := stream.byte_controller_
	if controller.queue_total_size_ > 0 {
		entry := controller.take_first_byte_queue_entry() or {
			return ReadPromise.rejected(err.msg())
		}
		value := bytes_value(unsafe {
			entry.buffer.data_[entry.byte_offset..entry.byte_offset + entry.byte_length]
		})
		readable_byte_stream_controller_handle_queue_drain(mut controller)
		return ReadPromise.fulfilled(value, false)
	}
	if size := stream.auto_allocate_size_ {
		controller.pending_pull_intos_.append(new_pull_into_descriptor(int(size), 1, 1, .default_reader))
	}
	promise := ReadPromise.pending()
	stream.pending_reads_.append(promise)
	readable_byte_stream_controller_call_pull_if_needed(mut controller)
	return promise
}

fn readable_byte_stream_controller_pull_into_descriptor(mut controller ReadableByteStreamController, descriptor PullIntoDescriptor, mut promise BYOBReadPromise) {
	mut stream := controller.stream_

	// ReadableByteStreamControllerPullInto, steps 11-15.
	if controller.pending_pull_intos_.len > 0 {
		controller.pending_pull_intos_.append(descriptor)
		readable_stream_add_read_into_request(mut stream, &promise)
		return
	}
	if stream.state_ == .closed {
		promise.resolve([], true)
		return
	}
	if controller.queue_total_size_ > 0 {
		mut filled_descriptor := descriptor
		if readable_byte_stream_controller_fill_pull_into_descriptor_from_queue(mut controller, mut filled_descriptor) {
			filled_view := pull_into_descriptor_bytes(&filled_descriptor)
			readable_byte_stream_controller_handle_queue_drain(mut controller)
			promise.resolve(filled_view, false)
			return
		}
		if stream.close_requested_ {
			reason := 'TypeError: Reader has been released'
			readable_byte_stream_controller_error(mut controller, string_value(reason))
			promise.reject(reason)
			return
		}
		controller.pending_pull_intos_.append(filled_descriptor)
	} else {
		controller.pending_pull_intos_.append(descriptor)
	}
	readable_stream_add_read_into_request(mut stream, &promise)
	readable_byte_stream_controller_call_pull_if_needed(mut controller)
}

fn readable_byte_stream_controller_pull_into_request(mut controller ReadableByteStreamController, view_length int, minimum int, mut promise BYOBReadPromise) {
	descriptor := new_pull_into_descriptor(view_length, minimum, 1, .byob)
	readable_byte_stream_controller_pull_into_descriptor(mut controller, descriptor, mut promise)
}

fn (mut reader ReadableStreamBYOBReader) read_into_existing_view(view []u8, minimum int) &BYOBReadPromise {
	if view.len == 0 || minimum <= 0 || minimum > view.len {
		return BYOBReadPromise.rejected('RangeError: Invalid BYOB tee view')
	}
	if reader.released_ || isnil(reader.stream_) {
		return BYOBReadPromise.rejected('TypeError: Cannot read from an empty stream')
	}
	mut promise := BYOBReadPromise.pending()
	mut stream := reader.stream_
	stream.disturbed_ = true
	if stream.state_ == .errored {
		promise.reject(stream.stored_error_)
		return promise
	}
	mut controller := stream.byte_controller_
	descriptor := new_pull_into_descriptor_for_view(view, minimum, .byob)
	readable_byte_stream_controller_pull_into_descriptor(mut controller, descriptor, mut promise)
	return promise
}

pub fn (mut stream ReadableStream) get_byob_reader() !&ReadableStreamBYOBReader {
	if !stream.byte_stream_ {
		return error('TypeError: BYOB readers require a readable byte stream')
	}
	if stream.locked() {
		return error('TypeError: ReadableStream is already locked')
	}
	mut closed := VoidPromise.pending()
	if stream.state_ == .closed {
		closed.resolve()
	} else if stream.state_ == .errored {
		closed.reject(stream.stored_error_)
	}
	reader := &ReadableStreamBYOBReader{
		stream_: &stream
		closed_: closed
	}
	stream.reader_kind_ = .byob
	stream.byob_reader_ = reader
	return reader
}

@[heap]
pub struct ReadableStreamBYOBReader {
mut:
	stream_             &ReadableStream = unsafe { nil }
	closed_             &VoidPromise = unsafe { nil }
	released_           bool
	read_into_requests_ []&BYOBReadPromise
}

pub fn ReadableStreamBYOBReader.construct_impl(mut stream ReadableStream) !&ReadableStreamBYOBReader {
	return stream.get_byob_reader()
}

pub fn (reader &ReadableStreamBYOBReader) closed() &VoidPromise {
	return reader.closed_
}

pub fn (mut reader ReadableStreamBYOBReader) read(view_length int, minimum int) &BYOBReadPromise {
	// ReadableStreamBYOBReader::read, adapted to the V byte-view model.
	if view_length <= 0 {
		return BYOBReadPromise.rejected('TypeError: Cannot read in an empty buffer')
	}
	if minimum <= 0 {
		return BYOBReadPromise.rejected('TypeError: options["min"] cannot have a value of 0')
	}
	if minimum > view_length {
		return BYOBReadPromise.rejected('RangeError: minimum exceeds the length of the view')
	}
	if reader.released_ || isnil(reader.stream_) {
		return BYOBReadPromise.rejected('TypeError: Cannot read from an empty stream')
	}
	mut promise := BYOBReadPromise.pending()
	mut stream := reader.stream_
	stream.disturbed_ = true
	if stream.state_ == .errored {
		promise.reject(stream.stored_error_)
		return promise
	}
	mut controller := stream.byte_controller_
	readable_byte_stream_controller_pull_into_request(mut controller, view_length, minimum, mut promise)
	return promise
}

pub fn (mut reader ReadableStreamBYOBReader) cancel(reason Value) &VoidPromise {
	if reader.released_ || isnil(reader.stream_) {
		return VoidPromise.rejected('TypeError: Reader has no associated stream')
	}
	mut stream := reader.stream_
	return stream.cancel_internal(reason)
}

pub fn (mut reader ReadableStreamBYOBReader) release_lock() ! {
	if reader.released_ || isnil(reader.stream_) {
		return
	}
	readable_stream_byob_reader_generic_release(mut reader)
	for mut request in reader.read_into_requests_ {
		request.reject('TypeError: Reader has been released')
	}
	reader.read_into_requests_.clear()
}

fn readable_stream_byob_reader_generic_release(mut reader ReadableStreamBYOBReader) {
	mut stream := reader.stream_
	if stream.state_ == .readable {
		mut closed := reader.closed_
		closed.reject('TypeError: Reader has been released')
	} else {
		reader.closed_ = VoidPromise.rejected('TypeError: Reader has been released')
	}
	mut controller := stream.byte_controller_
	controller.release_steps()
	stream.reader_kind_ = .none
	stream.byob_reader_ = unsafe { nil }
	reader.released_ = true
	reader.stream_ = unsafe { nil }
}

@[heap]
pub struct ReadableStreamBYOBRequest {
mut:
	controller_     &ReadableByteStreamController = unsafe { nil }
	view_           []u8
	active_         bool
	written_length_ int
}

pub fn (request &ReadableStreamBYOBRequest) view() ?[]u8 {
	if !request.active_ {
		return none
	}
	return unsafe { request.view_ }
}

// This helper represents writes through the ArrayBufferView returned by view().
pub fn (mut request ReadableStreamBYOBRequest) write_view(bytes []u8) ! {
	if !request.active_ || isnil(request.controller_) {
		return error('TypeError: BYOB request is inactive')
	}
	if bytes.len > request.view_.len {
		return error('RangeError: Bytes exceed the BYOB view')
	}
	copy(mut request.view_[..bytes.len], bytes)
	request.written_length_ = bytes.len
}

pub fn (mut request ReadableStreamBYOBRequest) respond(bytes_written u64) ! {
	if !request.active_ || isnil(request.controller_) {
		return error('TypeError: Controller is undefined')
	}
	if bytes_written > u64(request.view_.len) {
		return error('RangeError: bytesWritten exceeds the BYOB view')
	}
	mut controller := request.controller_
	readable_byte_stream_controller_respond(mut controller, bytes_written)!
}

pub fn (mut request ReadableStreamBYOBRequest) respond_with_new_view(view []u8) ! {
	if !request.active_ || isnil(request.controller_) {
		return error('TypeError: Controller is undefined')
	}
	mut controller := request.controller_
	readable_byte_stream_controller_respond_with_new_view(mut controller, view)!
}
