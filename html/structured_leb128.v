// Copyright (c) 2020-2024, the SerenityOS and Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// Structured storage uses vlib's LEB128 codec; IPC keeps its fixed-width format.
module html

import encoding.leb128

@[manualfree]
fn (mut serializer StructuredSerializer) write_unsigned_leb128(input u64) {
	encoded := leb128.encode_u64(input)
	serializer.data << encoded
	unsafe { encoded.free() }
}

@[manualfree]
fn (mut serializer StructuredSerializer) write_i32(input i32) {
	if serializer.type_ == .ipc {
		serializer.write_u32(u32(input))
		return
	}
	encoded := leb128.encode_i32(input)
	serializer.data << encoded
	unsafe { encoded.free() }
}

@[manualfree]
fn (mut serializer StructuredSerializer) write_i64(input i64) {
	if serializer.type_ == .ipc {
		serializer.write_fixed_u64(u64(input))
		return
	}
	encoded := leb128.encode_i64(input)
	serializer.data << encoded
	unsafe { encoded.free() }
}

// vlib returns a positive consumed count on success, zero for truncated input,
// and a negative consumed count for overflow. Preserve the source stream's
// cursor movement on failures as well as its DataCloneError messages.
fn (mut decoder StructuredDecoder) consume_leb128(count int, signed bool) ! {
	if count > 0 {
		decoder.offset += count
		return
	}
	if count == 0 {
		decoder.offset = decoder.data.len
		return error('DataCloneError: truncated serialization record')
	}
	decoder.offset -= count
	if signed {
		return error('DataCloneError: LEB128 value does not fit its source signed integer type')
	}
	return error('DataCloneError: LEB128 value does not fit its source integer type')
}

fn (mut decoder StructuredDecoder) read_unsigned_leb128(bits int) !u64 {
	// Storage uses u16, u32 and u64. Bound the vlib input to the source width
	// before decoding, so excess padding cannot consume the following field.
	max_bytes := (bits + 6) / 7
	available := decoder.data.len - decoder.offset
	length := if available < max_bytes { available } else { max_bytes }
	value, consumed := leb128.decode_u64(decoder.data[decoder.offset..decoder.offset + length])
	mut count := consumed
	if count == 0 && length == max_bytes {
		count = -max_bytes
	} else if count > 0 && bits < 64 && value >> bits != 0 {
		count = -count
	}
	decoder.consume_leb128(count, false)!
	return value
}

fn (mut decoder StructuredDecoder) read_i32() !i32 {
	if decoder.type_ == .ipc {
		return i32(decoder.read_u32()!)
	}
	value, count := leb128.decode_i32(decoder.data[decoder.offset..])
	decoder.consume_leb128(count, true)!
	return value
}

fn (mut decoder StructuredDecoder) read_i64() !i64 {
	if decoder.type_ == .ipc {
		return i64(decoder.read_fixed_u64()!)
	}
	value, count := leb128.decode_i64(decoder.data[decoder.offset..])
	decoder.consume_leb128(count, true)!
	return value
}
