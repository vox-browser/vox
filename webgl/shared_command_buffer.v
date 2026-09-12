// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebGL/WebGLSharedCommandBuffer.h. A V byte array stands in
// for Core::AnonymousBuffer while retaining shared backing across adopted
// views in the standalone engine.
module webgl

import encoding.binary

pub const webgl_shared_data_region_offset = 128
pub const webgl_shared_default_data_region_capacity = 32 * 1024 * 1024

pub struct WebGLSharedCommandBuffer {
mut:
	buffer_ []u8
}

pub fn WebGLSharedCommandBuffer.create(data_region_capacity int) !WebGLSharedCommandBuffer {
	if data_region_capacity < 0
		|| data_region_capacity > max_int - webgl_shared_data_region_offset {
		return error('Invalid WebGL shared command buffer capacity')
	}
	return WebGLSharedCommandBuffer{
		buffer_: []u8{len: webgl_shared_data_region_offset + data_region_capacity}
	}
}

pub fn WebGLSharedCommandBuffer.create_default() !WebGLSharedCommandBuffer {
	return WebGLSharedCommandBuffer.create(webgl_shared_default_data_region_capacity)
}

pub fn WebGLSharedCommandBuffer.adopt_received_buffer(buffer []u8) ?WebGLSharedCommandBuffer {
	if buffer.len <= webgl_shared_data_region_offset {
		return none
	}
	return WebGLSharedCommandBuffer{
		buffer_: buffer
	}
}

pub fn (command_buffer &WebGLSharedCommandBuffer) is_valid() bool {
	return command_buffer.buffer_.len > webgl_shared_data_region_offset
}

pub fn (command_buffer &WebGLSharedCommandBuffer) buffer() []u8 {
	return command_buffer.buffer_
}

pub fn (command_buffer &WebGLSharedCommandBuffer) executed_flush_sequence_number() u64 {
	if !command_buffer.is_valid() {
		return 0
	}
	return binary.little_endian_u64_at(command_buffer.buffer_, 0)
}

pub fn (mut command_buffer WebGLSharedCommandBuffer) store_executed_flush_sequence_number(flush_sequence_number u64) {
	if !command_buffer.is_valid() {
		return
	}
	encoded := binary.little_endian_get_u64(flush_sequence_number)
	copy(mut command_buffer.buffer_[..8], encoded)
}

pub fn (command_buffer &WebGLSharedCommandBuffer) data_region() []u8 {
	if !command_buffer.is_valid() {
		return []u8{}
	}
	return command_buffer.buffer_[webgl_shared_data_region_offset..]
}
