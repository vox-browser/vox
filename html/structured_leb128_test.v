module html

struct StructuredUnsignedLebCase {
	bits  int
	value u64
	bytes []u8
}

struct StructuredSignedLebCase {
	bits  int
	value i64
	bytes []u8
}

fn test_structured_storage_unsigned_leb128_goldens_and_following_bytes() {
	cases := [
		StructuredUnsignedLebCase{16, 0, [u8(0)]},
		StructuredUnsignedLebCase{16, 127, [u8(127)]},
		StructuredUnsignedLebCase{16, 128, [u8(128), 1]},
		StructuredUnsignedLebCase{16, 65535, [u8(255), 255, 3]},
		StructuredUnsignedLebCase{32, 624485, [u8(229), 142, 38]},
		StructuredUnsignedLebCase{32, 4294967295, [u8(255), 255, 255, 255, 15]},
		StructuredUnsignedLebCase{64, 4294967296, [u8(128), 128, 128, 128, 16]},
		StructuredUnsignedLebCase{64, 18446744073709551615, [u8(255), 255, 255, 255, 255, 255,
			255, 255, 255, 1]},
	]
	for item in cases {
		mut writer := StructuredSerializer{ type_: .storage, data: [u8(42)] }
		writer.write_unsigned_leb128(item.value)
		assert writer.data[1..] == item.bytes
		writer.write_u8(85)
		mut reader := StructuredDecoder{ type_: .storage, data: writer.data, offset: 1 }
		assert reader.read_unsigned_leb128(item.bits)! == item.value
		assert reader.offset == 1 + item.bytes.len
		assert reader.read_u8()! == 85
		assert reader.offset == writer.data.len
	}
}

fn test_structured_storage_signed_leb128_goldens_and_following_bytes() {
	cases := [
		StructuredSignedLebCase{32, 0, [u8(0)]},
		StructuredSignedLebCase{32, -1, [u8(127)]},
		StructuredSignedLebCase{32, 63, [u8(63)]},
		StructuredSignedLebCase{32, 64, [u8(192), 0]},
		StructuredSignedLebCase{32, -64, [u8(64)]},
		StructuredSignedLebCase{32, -65, [u8(191), 127]},
		StructuredSignedLebCase{32, 2147483647, [u8(255), 255, 255, 255, 7]},
		StructuredSignedLebCase{32, -2147483648, [u8(128), 128, 128, 128, 120]},
		StructuredSignedLebCase{64, 0, [u8(0)]},
		StructuredSignedLebCase{64, -1, [u8(127)]},
		StructuredSignedLebCase{64, 64, [u8(192), 0]},
		StructuredSignedLebCase{64, -65, [u8(191), 127]},
		StructuredSignedLebCase{64, 9223372036854775807, [u8(255), 255, 255, 255, 255, 255, 255,
			255, 255, 0]},
		StructuredSignedLebCase{64, -9223372036854775807 - 1, [u8(128), 128, 128, 128, 128, 128,
			128, 128, 128, 127]},
	]
	for item in cases {
		mut writer := StructuredSerializer{ type_: .storage, data: [u8(42)] }
		if item.bits == 32 {
			writer.write_i32(i32(item.value))
		} else {
			writer.write_i64(item.value)
		}
		assert writer.data[1..] == item.bytes
		writer.write_u8(85)
		mut reader := StructuredDecoder{ type_: .storage, data: writer.data, offset: 1 }
		value := if item.bits == 32 { i64(reader.read_i32()!) } else { reader.read_i64()! }
		assert value == item.value
		assert reader.offset == 1 + item.bytes.len
		assert reader.read_u8()! == 85
	}
}

fn test_structured_storage_leb128_accepts_padding_within_each_integer_width() {
	for bits in [16, 32, 64] {
		for length in 2 .. (bits + 6) / 7 + 1 {
			for value in [u64(0), 1, 127] {
				mut data := []u8{len: length - 1, init: u8(128)}
				data[0] |= u8(value)
				data << [u8(0), 85]
				mut reader := StructuredDecoder{ type_: .storage, data: data }
				assert reader.read_unsigned_leb128(bits)! == value
				assert reader.offset == length
				assert reader.read_u8()! == 85
			}
		}
	}
	for bits in [32, 64] {
		for length in 2 .. (bits + 6) / 7 + 1 {
			for negative in [false, true] {
				mut data := []u8{len: length - 1, init: if negative { u8(255) } else { u8(128) }}
				data << if negative { u8(127) } else { u8(0) }
				data << u8(85)
				mut reader := StructuredDecoder{ type_: .storage, data: data }
				value := if bits == 32 { i64(reader.read_i32()!) } else { reader.read_i64()! }
				assert value == if negative { i64(-1) } else { i64(0) }
				assert reader.offset == length
				assert reader.read_u8()! == 85
			}
		}
	}
}

fn test_structured_storage_unsigned_leb128_terminal_width_and_failure_cursor() {
	for bits in [16, 32, 64] {
		length := (bits + 6) / 7
		max_terminal := if bits == 16 {
			3
		} else if bits == 32 {
			15
		} else {
			1
		}
		for terminal in 0 .. 256 {
			mut data := [u8(42)]
			data << []u8{len: length - 1, init: u8(128)}
			data << [u8(terminal), 85]
			mut reader := StructuredDecoder{ type_: .storage, data: data, offset: 1 }
			if value := reader.read_unsigned_leb128(bits) {
				assert terminal <= max_terminal
				assert value == u64(terminal) << ((length - 1) * 7)
			} else {
				assert terminal > max_terminal
				assert err.msg() == 'DataCloneError: LEB128 value does not fit its source integer type'
			}
			assert reader.offset == 1 + length
			assert reader.read_u8()! == 85
		}
	}
}

fn test_structured_storage_signed_leb128_terminal_width_and_failure_cursor() {
	for bits in [32, 64] {
		length := (bits + 6) / 7
		for terminal in 0 .. 256 {
			mut data := [u8(42)]
			data << []u8{len: length - 1, init: u8(128)}
			data << [u8(terminal), 85]
			valid := if bits == 32 {
				terminal <= 7 || (terminal >= 120 && terminal <= 127)
			} else {
				terminal == 0 || terminal == 127
			}
			mut reader := StructuredDecoder{ type_: .storage, data: data, offset: 1 }
			value := if bits == 32 {
				i64(reader.read_i32() or {
					assert !valid
					assert err.msg() == 'DataCloneError: LEB128 value does not fit its source signed integer type'
					assert reader.offset == 1 + length
					assert reader.read_u8()! == 85
					continue
				})
			} else {
				reader.read_i64() or {
					assert !valid
					assert err.msg() == 'DataCloneError: LEB128 value does not fit its source signed integer type'
					assert reader.offset == 1 + length
					assert reader.read_u8()! == 85
					continue
				}
			}
			assert valid
			expected := if bits == 32 {
				i64(if terminal <= 7 { terminal } else { terminal - 128 }) * 268435456
			} else if terminal == 0 {
				i64(0)
			} else {
				i64(-9223372036854775807) - 1
			}
			assert value == expected
			assert reader.offset == 1 + length
			assert reader.read_u8()! == 85
		}
	}
}

fn test_structured_storage_leb128_truncation_consumes_only_available_input() {
	for bits in [16, 32, 64] {
		for length in 0 .. (bits + 6) / 7 {
			mut data := [u8(42)]
			data << []u8{len: length, init: u8(128)}
			mut reader := StructuredDecoder{ type_: .storage, data: data, offset: 1 }
			if _ := reader.read_unsigned_leb128(bits) {
				assert false
			} else {
				assert err.msg() == 'DataCloneError: truncated serialization record'
			}
			assert reader.offset == data.len
			if bits == 16 { continue }
			mut signed_reader := StructuredDecoder{ type_: .storage, data: data, offset: 1 }
			if bits == 32 {
				if _ := signed_reader.read_i32() {
					assert false
				} else {
					assert err.msg() == 'DataCloneError: truncated serialization record'
				}
			} else {
				if _ := signed_reader.read_i64() {
					assert false
				} else {
					assert err.msg() == 'DataCloneError: truncated serialization record'
				}
			}
			assert signed_reader.offset == data.len
		}
	}
}

fn test_structured_storage_leb128_sequential_mixed_integer_reads() {
	mut writer := StructuredSerializer{ type_: .storage }
	writer.write_unsigned_leb128(65535)
	writer.write_i32(-65)
	writer.write_u32(128)
	writer.write_i64(-9223372036854775807 - 1)
	writer.write_u64(4294967296)
	writer.write_u8(85)
	assert writer.data == [u8(255), 255, 3, 191, 127, 128, 1, 128, 128, 128, 128, 128, 128, 128,
		128, 128, 127, 128, 128, 128, 128, 16, 85]
	mut reader := StructuredDecoder{ type_: .storage, data: writer.data }
	assert reader.read_unsigned_leb128(16)! == 65535
	assert reader.read_i32()! == -65
	assert reader.read_u32()! == 128
	assert reader.read_i64()! == -9223372036854775807 - 1
	assert reader.read_u64()! == 4294967296
	assert reader.read_u8()! == 85
	assert reader.offset == writer.data.len
}

fn test_structured_ipc_signed_integer_bytes_remain_fixed_width() {
	mut writer := StructuredSerializer{}
	writer.write_i32(-2147483648)
	writer.write_i64(-1)
	writer.write_u8(85)
	assert writer.data == [u8(0), 0, 0, 128, 255, 255, 255, 255, 255, 255, 255, 255, 85]
	mut reader := StructuredDecoder{ data: writer.data }
	assert reader.read_i32()! == -2147483648
	assert reader.offset == 4
	assert reader.read_i64()! == -1
	assert reader.offset == 12
	assert reader.read_u8()! == 85
	for length in 0 .. 4 {
		mut truncated := StructuredDecoder{ data: writer.data[..length] }
		if _ := truncated.read_i32() {
			assert false
		} else {
			assert err.msg() == 'DataCloneError: truncated serialization record'
		}
		assert truncated.offset == 0
	}
	for length in 0 .. 8 {
		mut truncated := StructuredDecoder{ data: writer.data[4..4 + length] }
		if _ := truncated.read_i64() {
			assert false
		} else {
			assert err.msg() == 'DataCloneError: truncated serialization record'
		}
		assert truncated.offset == 0
	}
}
