// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ReadableByteStreamController, ReadableStreamBYOBReader,
// ReadableStreamBYOBRequest, pull-into descriptors, and byte controller ops.
module streams

pub struct PullIntoDescriptor {
pub mut:
	buffer_byte_length int
	byte_offset        int
	byte_length        int
	bytes_filled       int
	minimum_fill       int
	element_size       int = 1
}

@[heap]
pub struct ReadableByteStreamController {
mut:
	stream_              &ReadableStream = unsafe { nil }
	pending_pull_intos_ []PullIntoDescriptor
}

pub fn (controller &ReadableByteStreamController) desired_size() ?f64 {
	return controller.stream_.desired_size()
}

pub fn (mut controller ReadableByteStreamController) enqueue(chunk []u8) ! {
	if chunk.len == 0 {
		return error('TypeError: Cannot enqueue a chunk with byte length zero')
	}
	mut stream := controller.stream_
	if stream.state_ != .readable || stream.close_requested_ {
		return error('TypeError: The byte controller cannot enqueue')
	}
	if stream.tee_branches_.len > 0 {
		for mut branch in stream.tee_branches_ {
			if branch.state_ == .readable {
				mut branch_controller := branch.byte_controller_
				branch_controller.enqueue(chunk.clone())!
			}
		}
		stream.disturbed_ = true
		return
	}
	if !isnil(stream.transfer_target_) {
		mut target_controller := stream.transfer_target_.byte_controller_
		target_controller.enqueue(chunk.clone())!
		stream.disturbed_ = true
		return
	}
	if !isnil(stream.pending_byob_) {
		stream.byob_buffer_ << chunk
		stream.fulfill_pending_byob_if_ready()
	} else if stream.auto_allocate_read_ && stream.pending_reads_.len > 0 {
		count := if chunk.len < stream.pending_byob_size_ {
			chunk.len
		} else {
			stream.pending_byob_size_
		}
		mut promise := stream.pending_reads_[0]
		stream.pending_reads_.delete(0)
		promise.resolve(bytes_value(chunk[..count]), false)
		stream.invalidate_auto_allocate_request()
		if count < chunk.len {
			remainder := chunk[count..].clone()
			stream.queue_.enqueue_value_with_size(bytes_value(remainder), f64(remainder.len))!
		}
	} else if stream.pending_reads_.len > 0 {
		mut promise := stream.pending_reads_[0]
		stream.pending_reads_.delete(0)
		promise.resolve(bytes_value(chunk), false)
	} else {
		stream.queue_.enqueue_value_with_size(bytes_value(chunk), f64(chunk.len))!
	}
	stream.call_pull_if_needed()
	pump_readable_pipe(mut stream)
}

pub fn (mut controller ReadableByteStreamController) close() ! {
	mut stream := controller.stream_
	if stream.state_ != .readable || stream.close_requested_ {
		return error('TypeError: The byte controller cannot close this stream')
	}
	if !isnil(stream.pending_byob_) && stream.byob_buffer_.len > 0
		&& stream.byob_buffer_.len < stream.pending_byob_min_ {
		return error('TypeError: Insufficient bytes to satisfy the pending BYOB read')
	}
	stream.close()
	pump_readable_pipe(mut stream)
}

pub fn (mut controller ReadableByteStreamController) error(reason string) {
	mut stream := controller.stream_
	stream.error(reason)
}

pub fn (mut controller ReadableByteStreamController) byob_request() ?&ReadableStreamBYOBRequest {
	mut stream := controller.stream_
	if isnil(stream.pending_byob_) && !stream.auto_allocate_read_ {
		return none
	}
	if isnil(stream.byob_request_) {
		remaining := stream.pending_byob_size_ - stream.byob_buffer_.len
		stream.byob_request_ = &ReadableStreamBYOBRequest{
			controller_: controller
			view_:       []u8{len: remaining}
			active_:     true
		}
	}
	return stream.byob_request_
}

fn (mut stream ReadableStream) invalidate_auto_allocate_request() {
	stream.auto_allocate_read_ = false
	stream.invalidate_byob_request()
}

fn (mut stream ReadableStream) invalidate_byob_request() {
	stream.pending_byob_size_ = 0
	stream.pending_byob_min_ = 0
	stream.byob_buffer_.clear()
	if !isnil(stream.byob_request_) {
		mut request := stream.byob_request_
		request.active_ = false
		request.controller_ = unsafe { nil }
		request.view_.clear()
		stream.byob_request_ = unsafe { nil }
	}
}

fn (mut stream ReadableStream) take_bytes_from_queue(capacity int) []u8 {
	mut output := []u8{cap: capacity}
	for output.len < capacity && !stream.queue_.is_empty() {
		value := stream.queue_.dequeue_value() or { break }
		if value.kind != .bytes {
			continue
		}
		remaining := capacity - output.len
		count := if value.bytes_.len < remaining { value.bytes_.len } else { remaining }
		output << value.bytes_[..count]
		if count < value.bytes_.len {
			remainder := value.bytes_[count..].clone()
			stream.queue_.queue_.insert(0, ValueWithSize{
				value: bytes_value(remainder)
				size:  f64(remainder.len)
			})
			stream.queue_.total_size_ += f64(remainder.len)
		}
	}
	return output
}

fn (mut stream ReadableStream) fulfill_pending_byob_if_ready() {
	if isnil(stream.pending_byob_) || stream.byob_buffer_.len < stream.pending_byob_min_ {
		return
	}
	count := if stream.byob_buffer_.len < stream.pending_byob_size_ {
		stream.byob_buffer_.len
	} else {
		stream.pending_byob_size_
	}
	result := stream.byob_buffer_[..count].clone()
	remainder := stream.byob_buffer_[count..].clone()
	mut promise := stream.pending_byob_
	promise.resolve(result, false)
	stream.pending_byob_ = unsafe { nil }
	stream.pending_byob_size_ = 0
	stream.pending_byob_min_ = 0
	stream.byob_buffer_.clear()
	if !isnil(stream.byob_request_) {
		mut request := stream.byob_request_
		request.active_ = false
		request.controller_ = unsafe { nil }
		request.view_.clear()
		stream.byob_request_ = unsafe { nil }
	}
	if remainder.len > 0 {
		stream.queue_.queue_.insert(0, ValueWithSize{
			value: bytes_value(remainder)
			size:  f64(remainder.len)
		})
		stream.queue_.total_size_ += f64(remainder.len)
	}
	if stream.close_requested_ && stream.queue_.is_empty() {
		stream.close_internal()
	}
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
	stream_   &ReadableStream = unsafe { nil }
	closed_   &VoidPromise    = unsafe { nil }
	released_ bool
}

pub fn ReadableStreamBYOBReader.construct_impl(mut stream ReadableStream) !&ReadableStreamBYOBReader {
	return stream.get_byob_reader()
}

pub fn (reader &ReadableStreamBYOBReader) closed() &VoidPromise {
	return reader.closed_
}

pub fn (mut reader ReadableStreamBYOBReader) read(view_length int, minimum int) &BYOBReadPromise {
	if reader.released_ || isnil(reader.stream_) {
		return BYOBReadPromise.rejected('TypeError: Reader has no associated stream')
	}
	if view_length <= 0 {
		return BYOBReadPromise.rejected('TypeError: Cannot read into an empty view')
	}
	if minimum <= 0 {
		return BYOBReadPromise.rejected('TypeError: minimum must be greater than zero')
	}
	if minimum > view_length {
		return BYOBReadPromise.rejected('RangeError: minimum exceeds the view length')
	}
	mut stream := reader.stream_
	stream.disturbed_ = true
	if stream.state_ == .errored {
		return BYOBReadPromise.rejected(stream.stored_error_)
	}
	if stream.state_ == .closed {
		return BYOBReadPromise.fulfilled([], true)
	}
	if !isnil(stream.pending_byob_) {
		return BYOBReadPromise.rejected('TypeError: This reader already has a pending read')
	}
	bytes := stream.take_bytes_from_queue(view_length)
	if bytes.len >= minimum {
		if stream.close_requested_ && stream.queue_.is_empty() {
			stream.close_internal()
		}
		return BYOBReadPromise.fulfilled(bytes, false)
	}
	promise := BYOBReadPromise.pending()
	stream.pending_byob_ = promise
	stream.pending_byob_size_ = view_length
	stream.pending_byob_min_ = minimum
	stream.byob_buffer_ = bytes
	stream.call_pull_if_needed()
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
	mut stream := reader.stream_
	if !isnil(stream.pending_byob_) {
		mut pending := stream.pending_byob_
		pending.reject('TypeError: Reader has been released')
		stream.pending_byob_ = unsafe { nil }
	}
	if stream.byob_buffer_.len > 0 {
		preserved := stream.byob_buffer_.clone()
		stream.queue_.queue_.insert(0, ValueWithSize{
			value: bytes_value(preserved)
			size:  f64(preserved.len)
		})
		stream.queue_.total_size_ += f64(preserved.len)
	}
	stream.invalidate_byob_request()
	stream.reader_kind_ = .none
	stream.byob_reader_ = unsafe { nil }
	reader.released_ = true
	reader.stream_ = unsafe { nil }
	if stream.state_ == .readable {
		mut closed := reader.closed_
		closed.reject('TypeError: Reader has been released')
	} else {
		reader.closed_ = VoidPromise.rejected('TypeError: Reader has been released')
	}
}

@[heap]
pub struct ReadableStreamBYOBRequest {
mut:
	controller_ &ReadableByteStreamController = unsafe { nil }
	view_       []u8
	active_     bool
}

pub fn (request &ReadableStreamBYOBRequest) view() ?[]u8 {
	if !request.active_ {
		return none
	}
	return request.view_.clone()
}

pub fn (mut request ReadableStreamBYOBRequest) write_view(bytes []u8) ! {
	if !request.active_ || isnil(request.controller_) {
		return error('TypeError: BYOB request is inactive')
	}
	if bytes.len > request.view_.len {
		return error('RangeError: Bytes exceed the BYOB view')
	}
	for index, byte in bytes {
		request.view_[index] = byte
	}
}

pub fn (mut request ReadableStreamBYOBRequest) respond(bytes_written u64) ! {
	if !request.active_ || isnil(request.controller_) {
		return error('TypeError: BYOB request is inactive')
	}
	if bytes_written > u64(request.view_.len) {
		return error('RangeError: bytesWritten exceeds the BYOB view')
	}
	mut stream := request.controller_.stream_
	total_written := stream.byob_buffer_.len + int(bytes_written)
	if total_written < stream.pending_byob_min_ && stream.state_ == .readable {
		return error('RangeError: bytesWritten does not satisfy minimum fill')
	}
	mut result := stream.byob_buffer_.clone()
	result << request.view_[..int(bytes_written)]
	if stream.auto_allocate_read_ {
		if stream.pending_reads_.len == 0 {
			return error('TypeError: Auto-allocated read request is missing')
		}
		mut promise := stream.pending_reads_[0]
		stream.pending_reads_.delete(0)
		promise.resolve(bytes_value(result), stream.state_ == .closed)
	} else {
		mut promise := stream.pending_byob_
		promise.resolve(result, stream.state_ == .closed)
		stream.pending_byob_ = unsafe { nil }
	}
	stream.pending_byob_size_ = 0
	stream.pending_byob_min_ = 0
	stream.byob_buffer_.clear()
	request.active_ = false
	request.controller_ = unsafe { nil }
	request.view_.clear()
	stream.byob_request_ = unsafe { nil }
	stream.auto_allocate_read_ = false
}

pub fn (mut request ReadableStreamBYOBRequest) respond_with_new_view(view []u8) ! {
	if !request.active_ || isnil(request.controller_) {
		return error('TypeError: BYOB request is inactive')
	}
	if view.len > request.view_.len {
		return error('RangeError: Replacement view exceeds the pending BYOB view')
	}
	request.view_ = view.clone()
	request.respond(u64(view.len))!
}
