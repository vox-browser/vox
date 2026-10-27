module libjs

import math
import math.big

// Runtime/ArrayBuffer.h::RawBytesToNumeric/NumericToRawBytes and buffer element
// operations. The enum dispatch replaces the source's concrete C++ template
// specializations; the native binary16 scalar is the only C representation hook.
pub enum BufferElementType {
	big_int64
	big_uint64
	float16
	float32
	float64
	int8
	int16
	int32
	uint8
	uint16
	uint32
	uint8_clamped
}

pub fn (kind BufferElementType) size() uint {
	return match kind {
		.big_int64, .big_uint64, .float64 { uint(8) }
		.float32, .int32, .uint32 { uint(4) }
		.float16, .int16, .uint16 { uint(2) }
		else { uint(1) }
	}
}

pub fn (kind BufferElementType) is_bigint() bool {
	return kind in [.big_int64, .big_uint64]
}

pub fn raw_bytes_to_numeric(mut vm VM, kind BufferElementType, bytes []u8, little_endian bool) Value {
	return buffer_raw_bytes_to_numeric(kind, bytes, little_endian)
}

// Object's descriptor API has no VM argument. This conversion needs no VM
// state and creates standalone BigInt cells, like the other flattened cells.
fn buffer_raw_bytes_to_numeric(kind BufferElementType, bytes []u8, little_endian bool) Value {
	assert uint(bytes.len) == kind.size()
	mut raw := bytes.clone()
	if !little_endian {
		assert raw.len % 2 == 0
		for index in 0 .. raw.len / 2 {
			raw[index], raw[raw.len - 1 - index] = raw[raw.len - 1 - index], raw[index]
		}
	}
	// Explicit little-endian decoding replaces memcpy into the source's native
	// scalar, preserving its signed/unsigned interpretation without host alignment.
	mut bits := u64(0)
	for index, byte in raw {
		bits |= u64(byte) << u32(index * 8)
	}
	if kind in [.float16, .float32, .float64] {
		number := match kind {
			.float16 { float16_from_bits(u16(bits)) }
			.float32 { f64(math.f32_from_bits(u32(bits))) }
			else { math.f64_from_bits(bits) }
		}

		return Value.from_f64(if math.is_nan(number) { math.nan() } else { number })
	}
	return match kind {
		.big_int64 { Value.from_bigint(BigInt.create(big.integer_from_i64(i64(bits)))) }
		.big_uint64 { Value.from_bigint(BigInt.create(big.integer_from_u64(bits))) }
		.int8 { Value.from_i32(i32(i8(bits))) }
		.int16 { Value.from_i32(i32(i16(bits))) }
		.int32 { Value.from_i32(i32(bits)) }
		else { Value.from_f64(f64(bits)) }
	}
}

pub fn numeric_to_raw_bytes(mut vm VM, kind BufferElementType, value Value, little_endian bool) []u8 {
	assert value.is_number() || value.is_bigint()
	bits := match kind {
		.float16 { u64(float16_bits(value.to_number(mut vm) or { panic(err) }.number)) }
		.float32 { u64(math.f32_bits(f32(value.to_number(mut vm) or { panic(err) }.number))) }
		.float64 { math.f64_bits(value.to_number(mut vm) or { panic(err) }.number) }
		.big_int64 { u64(value.to_bigint_int64(mut vm) or { panic(err) }) }
		.big_uint64 { value.to_bigint_uint64(mut vm) or { panic(err) } }
		.int8 { u64(u8(value.to_i8(mut vm) or { panic(err) })) }
		.int16 { u64(u16(value.to_i16(mut vm) or { panic(err) })) }
		.int32 { u64(u32(value.to_i32(mut vm) or { panic(err) })) }
		.uint8 { u64(value.to_u8(mut vm) or { panic(err) }) }
		.uint16 { u64(value.to_u16(mut vm) or { panic(err) }) }
		.uint32 { u64(value.to_u32(mut vm) or { panic(err) }) }
		.uint8_clamped { u64(value.to_u8_clamp(mut vm) or { panic(err) }) }
	}

	mut raw := []u8{len: int(kind.size())}
	for index in 0 .. raw.len {
		raw[index] = u8(bits >> u32(index * 8))
	}
	if !little_endian && raw.len % 2 == 0 {
		for index in 0 .. raw.len / 2 {
			raw[index], raw[raw.len - 1 - index] = raw[raw.len - 1 - index], raw[index]
		}
	}
	return raw
}

pub fn (buffer &ArrayBufferObject) get_value(mut vm VM, index uint, kind BufferElementType, is_typed_array bool, order BufferOrder, little_endian bool) Value {
	return buffer.read_numeric_value(index, kind, is_typed_array, order, little_endian)
}

fn (buffer &ArrayBufferObject) read_numeric_value(index uint, kind BufferElementType, is_typed_array bool, order BufferOrder, little_endian bool) Value {
	_ = is_typed_array
	_ = order
	assert !buffer.is_detached()
	assert index <= buffer.byte_length() && kind.size() <= buffer.byte_length() - index
	// The pinned source's active branch copies ordinary bytes, including for
	// shared records. Its shared-memory event/ordering branches remain FIXME.
	return buffer_raw_bytes_to_numeric(kind, buffer.read_bytes(index, kind.size()), little_endian)
}

pub fn (mut buffer ArrayBufferObject) set_value(mut vm VM, index uint, kind BufferElementType, value Value, is_typed_array bool, order BufferOrder, little_endian bool) {
	assert !buffer.is_detached()
	assert index <= buffer.byte_length() && kind.size() <= buffer.byte_length() - index
	assert if kind.is_bigint() {
		value.is_bigint()
	} else {
		value.is_number()
	}
	buffer.overwrite(index, numeric_to_raw_bytes(mut vm, kind, value, little_endian))
}

pub type ReadWriteModifyFunction = fn (read []u8, argument []u8) []u8

pub fn (mut buffer ArrayBufferObject) get_modify_set_value(mut vm VM, index uint, kind BufferElementType, value Value, operation ReadWriteModifyFunction, little_endian bool) Value {
	raw := numeric_to_raw_bytes(mut vm, kind, value, little_endian)
	read := buffer.read_bytes(index, kind.size())
	modified := operation(read, raw)
	buffer.overwrite(index, modified)
	return raw_bytes_to_numeric(mut vm, kind, read, little_endian)
}
