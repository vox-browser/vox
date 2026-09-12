// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebGL/WebGLContextProxyBase.{h,cpp}. The V transport keeps
// published batches in memory, preserving the shared-buffer ownership and
// flush sequencing rules used across WebContent and the compositor.
module webgl

pub const webgl_max_pending_command_bytes = 4 * 1024 * 1024
pub const webgl_max_bitmap_attachments_per_message = 15
pub const webgl_reserved_bitmap_command_size = 256

pub struct WebGLTransportBatch {
pub:
	bytes                 []u8
	shared_buffer_offset  int
	flush_sequence_number u64
	bitmap_count          int
	uses_shared_buffer    bool
}

@[heap]
pub struct WebGLContextProxyBase {
pub:
	webgl_version WebGLVersion
mut:
	supported_extensions_          []string
	shared_command_buffer_         WebGLSharedCommandBuffer
	shared_data_cursor_            int
	shared_data_flush_base_        int
	last_published_flush_sequence_ u64
	out_of_line_commands_          WebGLCommandList
	pending_bitmaps_               [][]u8
	transmitted_batches_           []WebGLTransportBatch
	max_pending_command_bytes_     int = webgl_max_pending_command_bytes
	next_object_id_                WebGLObjectId = 1
	lost_                          bool
	pending_local_error_           GLenum
	wait_for_execution_succeeds_   bool = true
	next_sync_reply_               []u8
}

pub fn WebGLContextProxyBase.new(version WebGLVersion, supported_extensions []string, data_region_capacity int) !&WebGLContextProxyBase {
	mut proxy := &WebGLContextProxyBase{
		webgl_version: version
		supported_extensions_: supported_extensions.clone()
	}
	proxy.initialize_shared_command_buffer(data_region_capacity)!
	return proxy
}

pub fn (mut proxy WebGLContextProxyBase) restore(supported_extensions []string, data_region_capacity int) ! {
	proxy.supported_extensions_ = supported_extensions.clone()
	proxy.lost_ = false
	proxy.out_of_line_commands_.clear_with_capacity()
	proxy.pending_bitmaps_.clear()
	proxy.transmitted_batches_.clear()
	proxy.pending_local_error_ = no_error
	proxy.initialize_shared_command_buffer(data_region_capacity)!
}

pub fn (mut proxy WebGLContextProxyBase) initialize_shared_command_buffer(data_region_capacity int) ! {
	proxy.shared_data_cursor_ = 0
	proxy.shared_data_flush_base_ = 0
	proxy.last_published_flush_sequence_ = 0
	proxy.shared_command_buffer_ = WebGLSharedCommandBuffer.create(data_region_capacity)!
}

pub fn (mut proxy WebGLContextProxyBase) disable_shared_command_buffer() {
	proxy.shared_command_buffer_ = WebGLSharedCommandBuffer{}
	proxy.shared_data_cursor_ = 0
	proxy.shared_data_flush_base_ = 0
}

pub fn (mut proxy WebGLContextProxyBase) record_bytes(type_ WebGLCommandType, payload []u8, inline_data []u8) ! {
	if proxy.lost_ {
		return
	}

	if !proxy.shared_command_buffer_.is_valid() {
		proxy.out_of_line_commands_.append_bytes(type_, payload, inline_data)!
		if proxy.out_of_line_commands_.size_in_bytes() >= proxy.max_pending_command_bytes_ {
			proxy.flush_commands()
		}
		return
	}

	record_size := WebGLCommandList.padded_record_size(payload, inline_data)!
	data_region_size := proxy.shared_command_buffer_.data_region().len
	if record_size > data_region_size {
		proxy.flush_commands()
		mut oversized_commands := WebGLCommandList{}
		oversized_commands.append_bytes(type_, payload, inline_data)!
		proxy.transmitted_batches_ << WebGLTransportBatch{
			bytes: oversized_commands.buffer()
			bitmap_count: proxy.pending_bitmaps_.len
		}
		proxy.pending_bitmaps_.clear()
		return
	}

	proxy.rewind_shared_data_cursor_if_all_published_commands_executed()
	proxy.ensure_shared_data_capacity(record_size)!
	if proxy.lost_ {
		return
	}
	mut data_region := proxy.shared_command_buffer_.data_region()
	WebGLCommandList.write_record(mut data_region[proxy.shared_data_cursor_..proxy.shared_data_cursor_ + record_size], type_, payload, inline_data)!
	proxy.shared_data_cursor_ += record_size
	if proxy.shared_data_cursor_ - proxy.shared_data_flush_base_ >= proxy.max_pending_command_bytes_ {
		proxy.flush_commands()
	}
}

pub fn (mut proxy WebGLContextProxyBase) rewind_shared_data_cursor_if_all_published_commands_executed() {
	if proxy.shared_data_cursor_ == 0
		|| proxy.shared_data_cursor_ != proxy.shared_data_flush_base_ {
		return
	}
	if proxy.shared_command_buffer_.executed_flush_sequence_number() >= proxy.last_published_flush_sequence_ {
		proxy.shared_data_cursor_ = 0
		proxy.shared_data_flush_base_ = 0
	}
}

pub fn (mut proxy WebGLContextProxyBase) ensure_shared_data_capacity(record_size int) ! {
	data_region_capacity := proxy.shared_command_buffer_.data_region().len
	if record_size < 0 || record_size > data_region_capacity {
		return error('WebGL command record exceeds the shared data region')
	}
	if record_size <= data_region_capacity - proxy.shared_data_cursor_ {
		return
	}

	proxy.flush_commands()
	if proxy.shared_data_cursor_ != proxy.shared_data_flush_base_ {
		return error('WebGL shared command cursor was not published')
	}
	if proxy.shared_command_buffer_.executed_flush_sequence_number() < proxy.last_published_flush_sequence_ {
		if !proxy.wait_for_execution_succeeds_ {
			proxy.set_lost()
			return
		}
		proxy.shared_command_buffer_.store_executed_flush_sequence_number(proxy.last_published_flush_sequence_)
	}
	proxy.shared_data_cursor_ = 0
	proxy.shared_data_flush_base_ = 0
}

pub fn (mut proxy WebGLContextProxyBase) flush_commands() {
	if proxy.shared_command_buffer_.is_valid() {
		if proxy.shared_data_cursor_ == proxy.shared_data_flush_base_ {
			return
		}
		proxy.last_published_flush_sequence_++
		data_region := proxy.shared_command_buffer_.data_region()
		start := proxy.shared_data_flush_base_
		end := proxy.shared_data_cursor_
		proxy.transmitted_batches_ << WebGLTransportBatch{
			bytes: data_region[start..end].clone()
			shared_buffer_offset: start
			flush_sequence_number: proxy.last_published_flush_sequence_
			bitmap_count: proxy.pending_bitmaps_.len
			uses_shared_buffer: true
		}
		proxy.shared_data_flush_base_ = proxy.shared_data_cursor_
		proxy.pending_bitmaps_.clear()
		return
	}

	if proxy.out_of_line_commands_.is_empty() {
		return
	}
	proxy.transmitted_batches_ << WebGLTransportBatch{
		bytes: proxy.out_of_line_commands_.buffer()
		bitmap_count: proxy.pending_bitmaps_.len
	}
	proxy.out_of_line_commands_.clear_with_capacity()
	proxy.pending_bitmaps_.clear()
}

pub fn (mut proxy WebGLContextProxyBase) append_pending_bitmap(frame []u8) !u32 {
	if proxy.pending_bitmaps_.len >= webgl_max_bitmap_attachments_per_message {
		proxy.flush_commands()
	}
	if proxy.shared_command_buffer_.is_valid() {
		proxy.ensure_shared_data_capacity(webgl_reserved_bitmap_command_size)!
	}
	bitmap_index := u32(proxy.pending_bitmaps_.len)
	proxy.pending_bitmaps_ << frame.clone()
	return bitmap_index
}

pub fn (mut proxy WebGLContextProxyBase) send_sync_call(request []u8) []u8 {
	if proxy.lost_ {
		return []u8{}
	}
	proxy.flush_commands()
	reply := proxy.next_sync_reply_.clone()
	proxy.next_sync_reply_.clear()
	if reply.len == 0 {
		proxy.set_lost()
	}
	return reply
}

pub fn (mut proxy WebGLContextProxyBase) set_next_sync_reply(reply []u8) {
	proxy.next_sync_reply_ = reply.clone()
}

pub fn (mut proxy WebGLContextProxyBase) acknowledge_flush(sequence_number u64) {
	proxy.shared_command_buffer_.store_executed_flush_sequence_number(sequence_number)
}

pub fn (proxy &WebGLContextProxyBase) transmitted_batches() []WebGLTransportBatch {
	return proxy.transmitted_batches_.clone()
}

pub fn (mut proxy WebGLContextProxyBase) set_lost() {
	proxy.lost_ = true
}

pub fn (proxy &WebGLContextProxyBase) is_lost() bool {
	return proxy.lost_
}

pub fn (proxy &WebGLContextProxyBase) canvas_id() ?u64 {
	if proxy.lost_ {
		return none
	}
	return u64(voidptr(proxy))
}

pub fn (proxy &WebGLContextProxyBase) get_supported_opengl_extensions() []string {
	return proxy.supported_extensions_.clone()
}

pub fn (mut proxy WebGLContextProxyBase) allocate_object_id() WebGLObjectId {
	id := proxy.next_object_id_
	proxy.next_object_id_++
	return id
}

pub fn (mut proxy WebGLContextProxyBase) set_pending_local_error(error_value GLenum) {
	if proxy.pending_local_error_ == no_error {
		proxy.pending_local_error_ = error_value
	}
}

pub fn (mut proxy WebGLContextProxyBase) take_pending_local_error() GLenum {
	error_value := proxy.pending_local_error_
	proxy.pending_local_error_ = no_error
	return error_value
}
