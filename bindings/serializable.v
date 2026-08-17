// Copyright (c) 2024-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Bindings/Serializable.h. The byte encoder/decoder are the
// V boundary corresponding to the upstream IPC transfer-data streams.
module bindings

pub struct TransferDataEncoder {
pub mut:
	data []u8
}

pub fn (mut encoder TransferDataEncoder) write(bytes []u8) {
	encoder.data << bytes
}

pub struct TransferDataDecoder {
pub:
	data []u8
pub mut:
	offset int
}

pub fn (mut decoder TransferDataDecoder) read(length int) ![]u8 {
	if length > decoder.data.len - decoder.offset {
		return error('DataCloneError: truncated transfer data')
	}
	bytes := decoder.data[decoder.offset..decoder.offset + length].clone()
	decoder.offset += length
	return bytes
}

pub struct SerializationMemory {
pub mut:
	object_indices map[u64]u32
}

pub struct DeserializationMemory {
pub mut:
	objects map[u32]voidptr
}

pub interface Serializable {
	serialization_steps(mut encoder TransferDataEncoder, for_storage bool, mut memory SerializationMemory) !
	deserialization_steps(mut decoder TransferDataDecoder, mut memory DeserializationMemory) !
}
