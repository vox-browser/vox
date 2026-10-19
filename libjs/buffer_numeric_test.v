module libjs

import math

fn test_buffer_numeric_integer_layouts_endianness_and_bigint_modulo_are_exact() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	kinds := [BufferElementType.int8, .uint8, .int16, .uint16, .int32, .uint32, .big_int64,
		.big_uint64, .uint8_clamped]
	values := [Value.from_i32(-1), Value.from_i32(258), Value.from_i32(-258),
		Value.from_i32(65537), Value.from_f64(-2147483649), Value.from_f64(4294967297),
		Value.from_bigint(string_to_bigint(utf16_string('18446744073709551615')) or { panic('invalid BigInt literal') }),
		Value.from_bigint(string_to_bigint(utf16_string('-18446744073709551617')) or { panic('invalid BigInt literal') }),
		Value.from_f64(2.5)]
	expected := [[u8(255)], [u8(2)], [u8(254), 254], [u8(1), 0],
		[u8(255), 255, 255, 127], [u8(1), 0, 0, 0], [u8(255), 255, 255, 255, 255, 255, 255, 255],
		[u8(255), 255, 255, 255, 255, 255, 255, 255], [u8(2)]]
	numbers := [-1.0, 2, -258, 1, 2147483647, 1, 0, 0, 2]
	for index, kind in kinds {
		for little_endian in [true, false] {
			if kind.size() == 1 && !little_endian { continue
			 }
			bytes := numeric_to_raw_bytes(mut vm, kind, values[index], little_endian)
			assert bytes == if little_endian {
				expected[index]
			} else {
				expected[index].reverse()
			}
			value := raw_bytes_to_numeric(mut vm, kind, bytes, little_endian)
			if kind.is_bigint() {
				assert value.as_bigint().big_integer.str() == if kind == .big_int64 {
					'-1'
				} else {
					'18446744073709551615'
				}
			} else {
				assert value.number == numbers[index]
			}
		}
	}
}

fn test_buffer_float_formats_preserve_special_values_and_halfway_rounding() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for kind in [BufferElementType.float16, .float32, .float64] {
		for little_endian in [false, true] {
			for number in [0.0, -0.0, 1.5, math.inf(1), math.inf(-1),
				math.nan()] {
				bytes := numeric_to_raw_bytes(mut vm, kind, Value.from_f64(number), little_endian)
				decoded := raw_bytes_to_numeric(mut vm, kind, bytes, little_endian)
				assert same_value(decoded, Value.from_f64(number))
			}
		}
	}
	for number, expected in {
		1.00048828125:               u16(0x3c00)
		1.0004882812500002:          u16(0x3c01)
		1.00146484375:               u16(0x3c02)
		65504.0:                     u16(0x7bff)
		65520.0:                     u16(0x7c00)
		0.0000000298023223876953125: u16(0)
		0.000000059604644775390625:  u16(1)
	} {
		assert float16_bits(number) == expected
	}
	// Every finite/Infinity binary16 value round-trips exactly. NaN payloads are
	// intentionally canonicalized by RawBytesToNumeric, as in the source.
	for bits in 0 .. 65536 {
		if bits & 0x7c00 == 0x7c00 && bits & 0x03ff != 0 {
			assert math.is_nan(float16_from_bits(u16(bits)))
		} else {
			assert float16_bits(float16_from_bits(u16(bits))) == u16(bits)
		}
	}
	assert numeric_to_raw_bytes(mut vm, .float32, Value.from_f64(1.5), true) == [
		u8(0),
		0,
		192,
		63,
	]
	assert numeric_to_raw_bytes(mut vm, .float64, Value.from_f64(1.5), false) == [
		u8(63),
		248,
		0,
		0,
		0,
		0,
		0,
		0,
	]
}

fn test_buffer_element_reads_writes_and_modify_callbacks_use_the_requested_subrange() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut storage := &ByteBufferStorage{
		bytes: [u8(9), 0, 0, 0, 0, 9]
	}
	mut buffer := ArrayBufferObject.create_from_host_buffer(vm.realm(), storage, false,
		vm.realm().array_buffer_prototype_record())
	alias := ArrayBufferObject.create_from_host_buffer(vm.realm(), storage, false,
		vm.realm().array_buffer_prototype_record())
	buffer.set_value(mut vm, 1, .uint32, Value.from_f64(0x12345678), false, .unordered, false)
	assert storage.bytes == [u8(9), 0x12, 0x34, 0x56, 0x78, 9]
	assert alias.get_value(mut vm, 1, .uint32, false, .seq_cst, true).number == 0x78563412
	old := buffer.get_modify_set_value(mut vm, 1, .uint16, Value.from_i32(255), fn (read []u8, argument []u8) []u8 {
		assert read == [u8(0x12), 0x34] && argument == [u8(0), 255]
		return [read[0] ^ argument[0], read[1] ^ argument[1]]
	}, false)
	assert old.number == 0x1234 && storage.bytes == [u8(9), 0x12, 0xcb, 0x56, 0x78, 9]
	buffer.detach_buffer()
	assert alias.get_value(mut vm, 1, .uint16, false, .unordered, false).number == 0x12cb
}
