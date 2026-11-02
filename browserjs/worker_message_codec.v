// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import platform

// Matches worker_process.h's payload limit. The envelope is private, versioned
// IPC, separate from LibWeb's structured serialization byte format.
const worker_message_max_bytes = 16 * 1024 * 1024
const worker_message_max_capacity = u64(9007199254740991)

pub enum WorkerTransferKind as u8 {
	buffer
	port
}

pub struct WorkerTransferSlot {
pub:
	kind WorkerTransferKind
	index u32
}

fn validate_worker_transfer_memory(record NativeArrayBufferTransferRecord) ! {
	if record.ports.len == 0 {
		if record.memory.len != 0 { return error('Buffer-only worker messages use implicit transfer order') }
		return
	}
	if record.memory.len != record.buffers.len + record.ports.len { return error('Invalid worker transfer memory length') }
	mut tokens := map[u64]bool{}
	for token in record.ports {
		if token == 0 || tokens[token] { return error('Invalid or duplicate worker MessagePort token') }
		tokens[token] = true
	}
	mut buffers := map[u32]bool{}
	mut ports := map[u32]bool{}
	for slot in record.memory {
		match slot.kind {
			.buffer {
				if slot.index >= u32(record.buffers.len) || buffers[slot.index] { return error('Invalid worker buffer transfer index') }
				buffers[slot.index] = true
			}
			.port {
				if slot.index >= u32(record.ports.len) || ports[slot.index] { return error('Invalid worker port transfer index') }
				ports[slot.index] = true
			}
		}
	}
}

fn worker_message_write_u32(mut bytes []u8, value u32) {
	for shift in [24, 16, 8, 0] { bytes << u8(value >> shift) }
}

fn worker_message_write_u64(mut bytes []u8, value u64) {
	for shift in [56, 48, 40, 32, 24, 16, 8, 0] { bytes << u8(value >> shift) }
}

// Own every byte before returning to the sending event loop. Shared backing
// stores cannot cross this process boundary through a same-process side table.
pub fn encode_worker_message(record NativeArrayBufferTransferRecord) ![]u8 {
	validate_worker_transfer_memory(record)!
	if record.serialized.type_ != .ipc || record.serialized.data.len == 0 {
		return error('Invalid worker structured serialization record')
	}
	if record.serialized.shared_array_buffers.len != 0 {
		return error('Worker shared backing-store transport is unavailable')
	}
	mut length := u64(12) + u64(record.serialized.data.len)
	if record.ports.len > 0 { length += 4 + u64(record.ports.len) * 8 + u64(record.memory.len) * 5 }
	for buffer in record.buffers {
		if maximum := buffer.max_byte_length {
			if maximum < u64(buffer.bytes.len) || maximum > worker_message_max_capacity {
				return error('Invalid worker ArrayBuffer capacity')
			}
		}
		length += u64(13) + u64(buffer.bytes.len)
		if length > u64(worker_message_max_bytes) { return error('Worker message exceeds the frame limit') }
	}
	if length > u64(worker_message_max_bytes) { return error('Worker message exceeds the frame limit') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut bytes := []u8{cap: int(length)}
	bytes << if record.ports.len > 0 { 'VXM2'.bytes() } else { 'VXM1'.bytes() }
	worker_message_write_u32(mut bytes, u32(record.serialized.data.len))
	worker_message_write_u32(mut bytes, u32(record.buffers.len))
	if record.ports.len > 0 { worker_message_write_u32(mut bytes, u32(record.ports.len)) }
	bytes << record.serialized.data
	for buffer in record.buffers {
		worker_message_write_u32(mut bytes, u32(buffer.bytes.len))
		bytes << u8(if buffer.max_byte_length != none { 1 } else { 0 })
		worker_message_write_u64(mut bytes, buffer.max_byte_length or { 0 })
		bytes << buffer.bytes
	}
	for token in record.ports { worker_message_write_u64(mut bytes, token) }
	for slot in record.memory {
		bytes << u8(slot.kind)
		worker_message_write_u32(mut bytes, slot.index)
	}
	return bytes
}

struct WorkerMessageReader {
	bytes []u8
mut:
	offset int
}

fn (mut reader WorkerMessageReader) take(length int) ![]u8 {
	if length < 0 || length > reader.bytes.len - reader.offset {
		return error('Truncated worker message')
	}
	start := reader.offset
	reader.offset += length
	return reader.bytes[start..reader.offset]
}

fn (mut reader WorkerMessageReader) read_u32() !u32 {
	bytes := reader.take(4)!
	return (u32(bytes[0]) << 24) | (u32(bytes[1]) << 16) | (u32(bytes[2]) << 8) | u32(bytes[3])
}

fn (mut reader WorkerMessageReader) read_u64() !u64 {
	bytes := reader.take(8)!
	mut value := u64(0)
	for byte in bytes { value = (value << 8) | u64(byte) }
	return value
}

// Framing validation precedes allocations derived from wire lengths. The graph
// itself is validated by the receiving realm's structured-clone decoder.
pub fn decode_worker_message(bytes []u8) !NativeArrayBufferTransferRecord {
	if bytes.len > worker_message_max_bytes { return error('Worker message exceeds the frame limit') }
	mut reader := WorkerMessageReader{bytes: bytes}
	version := reader.take(4)!
	if version != 'VXM1'.bytes() && version != 'VXM2'.bytes() { return error('Invalid worker message version') }
	graph_length := reader.read_u32()!
	buffer_count := reader.read_u32()!
	port_count := if version == 'VXM2'.bytes() { reader.read_u32()! } else { u32(0) }
	if version == 'VXM2'.bytes() && port_count == 0 { return error('Empty worker MessagePort transfer list') }
	if graph_length == 0 { return error('Empty worker structured serialization record') }
	graph := reader.take(int(graph_length))!
	if u64(buffer_count) * 13 + u64(port_count) * 8
		+ (if port_count > 0 { (u64(buffer_count) + u64(port_count)) * 5 } else { u64(0) }) > u64(bytes.len - reader.offset) {
		return error('Truncated worker transfer list')
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut buffers := []TransferredArrayBuffer{cap: int(buffer_count)}
	for _ in 0 .. int(buffer_count) {
		length := reader.read_u32()!
		kind := reader.take(1)![0]
		maximum := reader.read_u64()!
		if kind > 1 || (kind == 0 && maximum != 0) ||
			(kind == 1 && (maximum < u64(length) || maximum > worker_message_max_capacity)) {
			return error('Invalid worker ArrayBuffer capacity')
		}
		payload := reader.take(int(length))!
		buffers << TransferredArrayBuffer{
			bytes: payload.clone()
			max_byte_length: if kind == 1 { ?u64(maximum) } else { none }
		}
	}
	mut ports := []u64{cap: int(port_count)}
	for _ in 0 .. int(port_count) { ports << reader.read_u64()! }
	mut memory := []WorkerTransferSlot{}
	if port_count > 0 {
		for _ in 0 .. int(u64(buffer_count) + u64(port_count)) {
			kind := reader.take(1)![0]
			if kind > u8(WorkerTransferKind.port) { return error('Invalid worker transfer kind') }
			memory << WorkerTransferSlot{kind: unsafe { WorkerTransferKind(kind) }, index: reader.read_u32()!}
		}
	}
	if reader.offset != bytes.len { return error('Trailing worker message bytes') }
	record := NativeArrayBufferTransferRecord{
		serialized: html.SerializationRecord{data: graph.clone()}
		buffers: buffers
		ports: ports
		memory: memory
	}
	validate_worker_transfer_memory(record)!
	return record
}
