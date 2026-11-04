module libjs

fn assert_direct_usv_matches_repair(units []u16) {
	text := Utf16String{data: units}
	assert text.to_well_formed_utf8() == text.to_well_formed().str()
}

fn test_direct_usv_encoding_preserves_every_single_unit_and_valid_surrogate_pair() {
	mut units := [u16(0)]
	for value in 0 .. 0x10000 {
		units[0] = u16(value)
		assert_direct_usv_matches_repair(units)
	}
	units = [u16(0xd800), 0xdc00]
	for high in 0xd800 .. 0xdc00 {
		units[0] = u16(high)
		for low in 0xdc00 .. 0xe000 {
			units[1] = u16(low)
			assert_direct_usv_matches_repair(units)
		}
	}
}

fn test_direct_usv_encoding_preserves_surrogate_adjacencies_and_ascii_boundaries() {
	mut units := [u16(0), 0]
	for value in 0 .. 0x10000 {
		for neighbor in [u16(0), 65, 0xd7ff, 0xd800, 0xdbff, 0xdc00, 0xdfff, 0xe000, 0xffff] {
			units[0] = u16(value)
			units[1] = neighbor
			assert_direct_usv_matches_repair(units)
		}
	}
	for length in [0, 1, 15, 16, 31, 32, 63, 64, 255, 1024] {
		prefix := []u16{len: length, init: u16(65)}
		for tail in [ [u16(0xd800)], [u16(0xdc00)], [u16(0xd800), 0xd800, 0xdc00],
			[u16(0xd800), 0xdc00, 0xdc00], [u16(0), 0x754c, 0xd83d, 0xde00] ] {
			mut mixed := prefix.clone()
			mixed << tail
			assert_direct_usv_matches_repair(mixed)
		}
	}
}

fn test_direct_usv_encoding_retains_raw_ascii_contract_and_rejects_stale_bytes() {
	bytes := []u8{len: 256, init: u8(index)}
	mut text := utf16_string_from_ascii_without_validation(bytes)
	assert text.to_well_formed_utf8().bytes() == bytes
	text.data[0] = 0xd800
	assert text.to_well_formed_utf8() == text.to_well_formed().str()
	text.data = [u16(65)]
	assert text.to_well_formed_utf8() == 'A'
	for ascii in [false, true] {
		stored := utf16_string_from_code_units_with_storage([u16(65), 0], ascii)!
		assert stored.to_well_formed_utf8() == 'A\x00'
	}
	mut owned := utf16_string_from_code_units([u16(65), 0xd800, 0, 0xd83d, 0xde00])
	before := owned.code_units()
	result := owned.to_well_formed_utf8()
	assert owned.code_units() == before
	owned.data[0] = 66
	assert result == 'A\uFFFD\x00😀'
	assert utf16_string_from_code_units([]).to_well_formed_utf8() == ''
}
