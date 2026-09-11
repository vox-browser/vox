// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Typed IPC representation of the records encoded in Compositor/Types.cpp.
module compositor

import encoding.binary
import math
import painting

fn append_u32(mut output []u8, value u32) {
	output << binary.little_endian_get_u32(value)
}

fn append_u64(mut output []u8, value u64) {
	output << binary.little_endian_get_u64(value)
}

fn append_point(mut output []u8, point painting.Point) {
	append_u64(mut output, math.f64_bits(point.x))
	append_u64(mut output, math.f64_bits(point.y))
}

fn append_stable_node_id(mut output []u8, stable_node_id AsyncScrollNodeStableId) {
	append_u64(mut output, stable_node_id.node_id)
	output << u8(stable_node_id.kind)
	output << stable_node_id.pseudo_element_type
}

fn append_scroll_offset(mut output []u8, offset AsyncScrollOffset) {
	append_stable_node_id(mut output, offset.stable_node_id)
	append_point(mut output, offset.compositor_scroll_offset)
	append_point(mut output, offset.unadopted_scroll_delta)
}

pub fn encode_async_scroll_node_stable_id(stable_node_id AsyncScrollNodeStableId) []u8 {
	mut output := []u8{cap: 10}
	append_stable_node_id(mut output, stable_node_id)
	return output
}

pub fn encode_async_scroll_offset(offset AsyncScrollOffset) []u8 {
	mut output := []u8{cap: 42}
	append_scroll_offset(mut output, offset)
	return output
}

pub fn encode_pending_async_scroll_updates(updates PendingAsyncScrollUpdates) []u8 {
	mut output := []u8{}
	append_u64(mut output, updates.sequence)
	append_u32(mut output, u32(updates.scroll_offsets.len))
	for offset in updates.scroll_offsets {
		append_scroll_offset(mut output, offset)
	}
	append_u32(mut output, u32(updates.completed_operation_ids.len))
	for operation_id in updates.completed_operation_ids {
		append_u64(mut output, operation_id)
	}
	append_u32(mut output, u32(updates.operation_ids_taken_over_by_user_input.len))
	for operation_id in updates.operation_ids_taken_over_by_user_input {
		append_u64(mut output, operation_id)
	}
	output << u8(updates.user_scroll_gesture_in_progress)
	output << u8(updates.user_scroll_gesture_ended)
	return output
}

pub fn encode_async_scroll_enqueue_result(result AsyncScrollEnqueueResult) []u8 {
	mut output := [u8(result.accepted)]
	if operation_id := result.operation_id {
		output << u8(1)
		append_u64(mut output, operation_id)
	} else {
		output << u8(0)
	}
	return output
}

struct CompositorDecoder {
	input []u8
mut:
	offset int
}

fn (mut decoder CompositorDecoder) read_u8() !u8 {
	if decoder.offset >= decoder.input.len {
		return error('IPC: unexpected end of compositor message')
	}
	value := decoder.input[decoder.offset]
	decoder.offset++
	return value
}

fn (mut decoder CompositorDecoder) read_bool() !bool {
	value := decoder.read_u8()!
	if value > 1 {
		return error('IPC: invalid compositor boolean')
	}
	return value == 1
}

fn (mut decoder CompositorDecoder) read_u32() !u32 {
	if decoder.offset + 4 > decoder.input.len {
		return error('IPC: unexpected end of compositor message')
	}
	value := binary.little_endian_u32_at(decoder.input, decoder.offset)
	decoder.offset += 4
	return value
}

fn (mut decoder CompositorDecoder) read_u64() !u64 {
	if decoder.offset + 8 > decoder.input.len {
		return error('IPC: unexpected end of compositor message')
	}
	value := binary.little_endian_u64_at(decoder.input, decoder.offset)
	decoder.offset += 8
	return value
}

fn (mut decoder CompositorDecoder) read_point() !painting.Point {
	return painting.Point{
		x: math.f64_from_bits(decoder.read_u64()!)
		y: math.f64_from_bits(decoder.read_u64()!)
	}
}

fn (mut decoder CompositorDecoder) read_stable_node_id() !AsyncScrollNodeStableId {
	node_id := decoder.read_u64()!
	kind_value := decoder.read_u8()!
	if kind_value > u8(AsyncScrollNodeKind.pseudo_element) {
		return error('IPC: invalid async scroll node kind')
	}
	kind := match kind_value {
		0 { AsyncScrollNodeKind.viewport }
		1 { AsyncScrollNodeKind.element }
		else { AsyncScrollNodeKind.pseudo_element }
	}
	return AsyncScrollNodeStableId{
		node_id: node_id
		kind: kind
		pseudo_element_type: decoder.read_u8()!
	}
}

fn (mut decoder CompositorDecoder) read_scroll_offset() !AsyncScrollOffset {
	return AsyncScrollOffset{
		stable_node_id: decoder.read_stable_node_id()!
		compositor_scroll_offset: decoder.read_point()!
		unadopted_scroll_delta: decoder.read_point()!
	}
}

fn (decoder CompositorDecoder) ensure_finished() ! {
	if decoder.offset != decoder.input.len {
		return error('IPC: trailing bytes in compositor message')
	}
}

fn checked_count(count u32, remaining_bytes int, minimum_item_size int) !int {
	if minimum_item_size <= 0 || u64(count) * u64(minimum_item_size) > u64(remaining_bytes) {
		return error('IPC: invalid compositor vector length')
	}
	return int(count)
}

pub fn decode_async_scroll_node_stable_id(input []u8) !AsyncScrollNodeStableId {
	mut decoder := CompositorDecoder{ input: input }
	value := decoder.read_stable_node_id()!
	decoder.ensure_finished()!
	return value
}

pub fn decode_async_scroll_offset(input []u8) !AsyncScrollOffset {
	mut decoder := CompositorDecoder{ input: input }
	value := decoder.read_scroll_offset()!
	decoder.ensure_finished()!
	return value
}

pub fn decode_pending_async_scroll_updates(input []u8) !PendingAsyncScrollUpdates {
	mut decoder := CompositorDecoder{ input: input }
	sequence := decoder.read_u64()!
	offset_count := checked_count(decoder.read_u32()!, input.len - decoder.offset, 42)!
	mut scroll_offsets := []AsyncScrollOffset{cap: offset_count}
	for _ in 0 .. offset_count {
		scroll_offsets << decoder.read_scroll_offset()!
	}
	completed_count := checked_count(decoder.read_u32()!, input.len - decoder.offset, 8)!
	mut completed := []AsyncScrollOperationId{cap: completed_count}
	for _ in 0 .. completed_count {
		completed << AsyncScrollOperationId(decoder.read_u64()!)
	}
	taken_over_count := checked_count(decoder.read_u32()!, input.len - decoder.offset, 8)!
	mut taken_over := []AsyncScrollOperationId{cap: taken_over_count}
	for _ in 0 .. taken_over_count {
		taken_over << AsyncScrollOperationId(decoder.read_u64()!)
	}
	updates := PendingAsyncScrollUpdates{
		sequence: sequence
		scroll_offsets: scroll_offsets
		completed_operation_ids: completed
		operation_ids_taken_over_by_user_input: taken_over
		user_scroll_gesture_in_progress: decoder.read_bool()!
		user_scroll_gesture_ended: decoder.read_bool()!
	}
	decoder.ensure_finished()!
	return updates
}

pub fn decode_async_scroll_enqueue_result(input []u8) !AsyncScrollEnqueueResult {
	mut decoder := CompositorDecoder{ input: input }
	accepted := decoder.read_bool()!
	has_operation_id := decoder.read_bool()!
	operation_id := if has_operation_id {
		?AsyncScrollOperationId(decoder.read_u64()!)
	} else {
		?AsyncScrollOperationId(none)
	}
	decoder.ensure_finished()!
	return AsyncScrollEnqueueResult{
		accepted: accepted
		operation_id: operation_id
	}
}
