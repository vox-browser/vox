module jpegxl

import math

fn test_bit_reader_every_offset_and_width_matches_independent_bit_sequence() {
	data := [u8(0x91), 0xa7, 0x34, 0xe5, 0x1c, 0x80, 0xff, 0x42, 0x66, 0xb0, 0x05, 0x39]
	mut individual_bits := []u64{}
	for byte in data {
		for bit in 0 .. 8 { individual_bits << u64((byte >> bit) & 1) }
	}
	for offset in 0 .. data.len * 8 + 1 {
		for width in 0 .. 57 {
			mut reader := new_bit_reader(data)
			reader.skip(offset)!
			mut expected := u64(0)
			for bit in 0 .. math.min(width, individual_bits.len - offset) {
				expected |= individual_bits[offset + bit] << bit
			}
			assert reader.peek(width)! == expected
			assert reader.position == offset
			if width <= data.len * 8 - offset {
				assert reader.read(width)! == expected
				assert reader.position == offset + width
			} else {
				if _ := reader.read(width) {
					assert false
				}
				assert reader.position == offset
				assert reader.read_optimistic(width)! == expected
				if _ := reader.check_end() {
					assert false
				}
			}
		}
	}
}

fn test_split_bounds_padding_and_truncated_sections() {
	mut reader := new_bit_reader([u8(1), 0x35, 0x79, 0xab])
	assert reader.read(1)! == 1
	mut section := reader.split_bytes(2)!
	assert reader.position == 24
	assert section.read(16)! == 0x7935
	if _ := section.read(1) {
		assert false
	}
	assert reader.read(8)! == 0xab
	mut empty := reader.split_bytes(0)!
	assert empty.read(0)! == 0
	if _ := empty.read(1) {
		assert false
	}
	if _ := reader.split_bytes(1) {
		assert false
	}
	mut nonzero := new_bit_reader([u8(0x80), 0])
	nonzero.skip(1)!
	if _ := nonzero.align_to_byte() {
		assert false
	}
	mut invalid := new_bit_reader([u8(0xff)])
	if _ := invalid.read(-1) {
		assert false
	}
	if _ := invalid.read(57) {
		assert false
	}
	if _ := invalid.skip(-1) {
		assert false
	}
	if _ := invalid.split_bytes(-1) {
		assert false
	}
	if _ := invalid.skip(9) {
		assert false
	}
	assert invalid.available_bits() == 0
}

fn test_integer_extremes_signed_unpack_and_extensions() {
	assert unpack_signed(0) == 0
	assert unpack_signed(1) == -1
	assert unpack_signed(0xfffffffe) == i32(2147483647)
	assert unpack_signed(0xffffffff) == i32(-2147483648)
	// Selector 3, twelve bits, six (continuation + eight-bit) groups,
	// then a final continuation and four bits: all 64 result bits are one.
	mut maximum := new_bit_reader([u8(0xff), 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01])
	assert maximum.read_u64()! == ~u64(0)
	assert maximum.position == 73
	mut no_extensions := new_bit_reader([u8(0)])
	no_extensions.skip_extensions()!
	assert no_extensions.position == 2
	// Selector bitmap=1 (01,0000), first size=1 (01,0000), payload=one bit.
	mut extensions := new_bit_reader([u8(0x41), 0])
	extensions.skip_extensions()!
	assert extensions.position == 13
	mut truncated := new_bit_reader([u8(0x41)])
	if _ := truncated.skip_extensions() {
		assert false
	}
}

fn test_name_bytes_are_latin1_scalars_and_truncation_is_checked() {
	// Name length 2: selector 1 followed by four-bit value 2; unaligned Latin-1 bytes.
	mut reader := new_bit_reader([u8(0x49), 0xc0, 0x3f])
	assert reader.read_name()! == '\x01ÿ'
	mut empty := new_bit_reader([u8(0)])
	assert empty.read_name()! == ''
	mut truncated := new_bit_reader([u8(0x09)])
	if _ := truncated.read_name() {
		assert false
	}
}

fn test_truncated_names_and_extensions_preserve_source_consumption() {
	mut name := new_bit_reader([u8(0x09), 0])
	if _ := name.read_name() {
		assert false
	}
	assert name.position == 14
	mut extension := new_bit_reader([u8(0x81), 0, 0])
	if _ := extension.skip_extensions() {
		assert false
	}
	assert extension.position == 24
}

fn test_truncated_section_split_preserves_source_parent_consumption() {
	mut reader := new_bit_reader([u8(0x12), 0x34])
	if _ := reader.split_bytes(3) {
		assert false
	}
	assert reader.position == 16
	assert reader.available_bits() == 0
}
