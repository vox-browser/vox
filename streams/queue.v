// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the queue-with-sizes abstract operations in
// Streams/AbstractOperations.{h,cpp}.
module streams

import math

pub struct ValueWithSize {
pub:
	value Value
	size  f64
}

@[heap]
struct ValueWithSizeEntry {
mut:
	value ValueWithSize
	next_ &ValueWithSizeEntry = unsafe { nil }
}

// ReadableStreamDefaultController and WritableStreamDefaultController use an
// AK::SinglyLinkedList for this slot. Dequeueing the head must not shift every
// remaining stream chunk.
struct ValueWithSizeList {
mut:
	head_ &ValueWithSizeEntry = unsafe { nil }
	tail_ &ValueWithSizeEntry = unsafe { nil }
pub mut:
	len int
}

fn (mut list ValueWithSizeList) append(value ValueWithSize) {
	entry := &ValueWithSizeEntry{
		value: value
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

fn (list &ValueWithSizeList) first() !ValueWithSize {
	if isnil(list.head_) {
		return error('InternalError: Cannot inspect an empty stream queue')
	}
	return list.head_.value
}

fn (mut list ValueWithSizeList) shift() !ValueWithSize {
	if isnil(list.head_) {
		return error('InternalError: Cannot dequeue an empty stream queue')
	}
	mut entry := list.head_
	list.head_ = entry.next_
	entry.next_ = unsafe { nil }
	if isnil(list.head_) {
		list.tail_ = unsafe { nil }
	}
	list.len--
	return entry.value
}

fn (mut list ValueWithSizeList) clear() {
	list.head_ = unsafe { nil }
	list.tail_ = unsafe { nil }
	list.len = 0
}

fn (list &ValueWithSizeList) values() []ValueWithSize {
	mut values := []ValueWithSize{cap: list.len}
	mut entry := list.head_
	for !isnil(entry) {
		values << entry.value
		entry = entry.next_
	}
	return values
}

pub struct QueueWithSizes {
mut:
	queue_      ValueWithSizeList
	total_size_ f64
}

pub fn (queue &QueueWithSizes) len() int {
	return queue.queue_.len
}

pub fn (queue &QueueWithSizes) total_size() f64 {
	return queue.total_size_
}

pub fn (queue &QueueWithSizes) is_empty() bool {
	return queue.queue_.len == 0
}

pub fn (mut queue QueueWithSizes) enqueue_value_with_size(value Value, size f64) ! {
	if size < 0 || math.is_nan(size) {
		return error('RangeError: Chunk size must be a non-negative number')
	}
	if math.is_inf(size, 1) {
		return error('RangeError: Chunk size must be finite')
	}
	queue.queue_.append(ValueWithSize{
		value: value
		size: size
	})
	queue.total_size_ += size
}

pub fn (mut queue QueueWithSizes) dequeue_value() !Value {
	if queue.queue_.len == 0 {
		return error('InternalError: Cannot dequeue an empty stream queue')
	}
	entry := queue.queue_.shift()!
	queue.total_size_ -= entry.size
	if queue.total_size_ < 0 {
		queue.total_size_ = 0
	}
	return entry.value
}

pub fn (queue &QueueWithSizes) peek_queue_value() !Value {
	if queue.queue_.len == 0 {
		return error('InternalError: Cannot peek an empty stream queue')
	}
	return queue.queue_.first()!.value
}

pub fn (mut queue QueueWithSizes) reset() {
	queue.queue_.clear()
	queue.total_size_ = 0
}

pub fn is_non_negative_number(value f64) bool {
	return value >= 0 && !math.is_nan(value)
}

pub struct ArrayBuffer {
mut:
	data_     []u8
	detached_ bool
}

pub fn ArrayBuffer.from_bytes(bytes []u8) ArrayBuffer {
	return ArrayBuffer{
		data_: bytes.clone()
	}
}

pub fn (buffer &ArrayBuffer) bytes() []u8 {
	return buffer.data_.clone()
}

pub fn (buffer &ArrayBuffer) byte_length() int {
	return if buffer.detached_ { 0 } else { buffer.data_.len }
}

pub fn (buffer &ArrayBuffer) detached() bool {
	return buffer.detached_
}

pub fn can_transfer_array_buffer(buffer &ArrayBuffer) bool {
	return !buffer.detached_
}

pub fn transfer_array_buffer(mut buffer ArrayBuffer) !ArrayBuffer {
	if buffer.detached_ {
		return error('DataCloneError: ArrayBuffer is detached')
	}
	transferred := ArrayBuffer{
		data_: buffer.data_
	}
	buffer.data_ = []u8{}
	buffer.detached_ = true
	return transferred
}

pub fn clone_as_uint8_array(buffer &ArrayBuffer, offset int, length int) ![]u8 {
	if buffer.detached_ {
		return error('DataCloneError: ArrayBuffer is detached')
	}
	if offset < 0 || length < 0 || offset > buffer.data_.len || length > buffer.data_.len - offset {
		return error('RangeError: ArrayBuffer view is out of bounds')
	}
	return buffer.data_[offset..offset + length].clone()
}

pub fn can_copy_data_block_bytes_buffer(to &ArrayBuffer, to_index int, from &ArrayBuffer, from_index int, count int) bool {
	if to.detached_ || from.detached_ || to_index < 0 || from_index < 0 || count < 0 {
		return false
	}
	if voidptr(to) == voidptr(from) {
		return false
	}
	return to_index <= to.data_.len && count <= to.data_.len - to_index && from_index <= from.data_.len && count <= from.data_.len - from_index
}

pub fn structured_clone(value Value) Value {
	return value.clone()
}
