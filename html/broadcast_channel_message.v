// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of BroadcastChannelMessage.{h,cpp}.
module html

import dom

pub struct BroadcastChannelMessage {
pub:
	storage_key        string
	channel_name       string
	source_origin      dom.Origin
	serialized_message SerializationRecord
	source_process_id  int
	source_channel_id  u64
}

fn broadcast_message_append_u32(mut output []u8, value u32) {
	for shift in 0 .. 4 {
		output << u8(value >> (shift * 8))
	}
}

fn broadcast_message_append_u64(mut output []u8, value u64) {
	for shift in 0 .. 8 {
		output << u8(value >> (shift * 8))
	}
}

fn broadcast_message_append_bytes(mut output []u8, value []u8) {
	broadcast_message_append_u32(mut output, u32(value.len))
	output << value
}

pub fn encode_broadcast_channel_message(message BroadcastChannelMessage) []u8 {
	mut output := []u8{}
	broadcast_message_append_bytes(mut output, message.storage_key.bytes())
	broadcast_message_append_bytes(mut output, message.channel_name.bytes())
	broadcast_message_append_bytes(mut output, message.source_origin.serialize_for_ipc().bytes())
	broadcast_message_append_bytes(mut output, message.serialized_message.data)
	broadcast_message_append_u64(mut output, u64(i64(message.source_process_id)))
	broadcast_message_append_u64(mut output, message.source_channel_id)
	return output
}

struct BroadcastChannelMessageDecoder {
	data []u8
mut:
	offset int
}

fn (mut decoder BroadcastChannelMessageDecoder) read_u32() !u32 {
	if decoder.offset + 4 > decoder.data.len {
		return error('truncated BroadcastChannel message IPC data')
	}
	mut value := u32(0)
	for shift in 0 .. 4 {
		value |= u32(decoder.data[decoder.offset + shift]) << (shift * 8)
	}
	decoder.offset += 4
	return value
}

fn (mut decoder BroadcastChannelMessageDecoder) read_u64() !u64 {
	if decoder.offset + 8 > decoder.data.len {
		return error('truncated BroadcastChannel message IPC data')
	}
	mut value := u64(0)
	for shift in 0 .. 8 {
		value |= u64(decoder.data[decoder.offset + shift]) << (shift * 8)
	}
	decoder.offset += 8
	return value
}

fn (mut decoder BroadcastChannelMessageDecoder) read_bytes() ![]u8 {
	length := int(decoder.read_u32()!)
	if length < 0 || decoder.offset + length > decoder.data.len {
		return error('truncated BroadcastChannel message IPC field')
	}
	value := decoder.data[decoder.offset..decoder.offset + length].clone()
	decoder.offset += length
	return value
}

pub fn decode_broadcast_channel_message(data []u8) !BroadcastChannelMessage {
	mut decoder := BroadcastChannelMessageDecoder{
		data: data
	}
	storage_key := decoder.read_bytes()!
	channel_name := decoder.read_bytes()!
	source_origin := decoder.read_bytes()!
	serialized_message := decoder.read_bytes()!
	source_process_id := int(i64(decoder.read_u64()!))
	source_channel_id := decoder.read_u64()!
	if decoder.offset != data.len {
		return error('trailing BroadcastChannel message IPC data')
	}
	return BroadcastChannelMessage{
		storage_key: storage_key.bytestr()
		channel_name: channel_name.bytestr()
		source_origin: dom.origin_from_ipc(source_origin.bytestr())
		serialized_message: SerializationRecord{
			data: serialized_message
		}
		source_process_id: source_process_id
		source_channel_id: source_channel_id
	}
}
