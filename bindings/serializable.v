// Copyright (c) 2024-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Bindings/Serializable.h. The byte encoder/decoder are the
// V boundary corresponding to the upstream IPC transfer-data streams.
module bindings

pub struct TransferDataEncoder {
pub mut:
	data                  []u8
	buffer_has_been_taken bool
}

pub fn (mut encoder TransferDataEncoder) write(bytes []u8) {
	encoder.data << bytes
}

// V's transfer boundary is byte-oriented, so this is the concrete equivalent
// of the upstream IPC encoder's templated encode(T) customization point.
pub fn (mut encoder TransferDataEncoder) encode(bytes []u8) {
	encoder.write(bytes)
}

pub fn (encoder &TransferDataEncoder) buffer() []u8 {
	return encoder.data
}

pub fn (mut encoder TransferDataEncoder) take_buffer() []u8 {
	if encoder.buffer_has_been_taken {
		panic('TransferDataEncoder buffer has already been taken')
	}
	encoder.buffer_has_been_taken = true
	buffer := encoder.data.clone()
	encoder.data.clear()
	return buffer
}

pub fn (mut encoder TransferDataEncoder) append(record []u8) {
	if encoder.buffer_has_been_taken {
		panic('cannot append to a TransferDataEncoder after taking its buffer')
	}
	encoder.data << record
}

pub fn (mut encoder TransferDataEncoder) extend(data_holders []TransferDataEncoder) {
	for holder in data_holders {
		mut mutable_holder := holder
		encoder.data << mutable_holder.take_buffer()
	}
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

// See TransferDataEncoder.encode: typed values serialize to bytes at the V
// binding boundary and decode through this checked stream operation.
pub fn (mut decoder TransferDataDecoder) decode(length int) ![]u8 {
	return decoder.read(length)
}

pub fn (mut decoder TransferDataDecoder) decode_buffer() ![]u8 {
	header := decoder.read(4) or {
		return error('DataCloneError: Unable to allocate memory for transferred buffer')
	}
	length := int(u32(header[0]) | (u32(header[1]) << 8) | (u32(header[2]) << 16) |
		(u32(header[3]) << 24))
	return decoder.read(length) or {
		error('DataCloneError: Unable to allocate memory for transferred buffer')
	}
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
