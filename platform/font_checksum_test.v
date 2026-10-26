module platform

fn checksum_test_write_u32(mut bytes []u8, offset int, value u32) {
	bytes[offset] = u8(value >> 24)
	bytes[offset + 1] = u8(value >> 16)
	bytes[offset + 2] = u8(value >> 8)
	bytes[offset + 3] = u8(value)
}

fn checksum_test_record(mut bytes []u8, index int, tag string, offset u32, length u32) {
	record := 12 + index * 16
	for i in 0 .. 4 { bytes[record + i] = tag[i] }
	checksum_test_write_u32(mut bytes, record + 4, 0xdeadbeef)
	checksum_test_write_u32(mut bytes, record + 8, offset)
	checksum_test_write_u32(mut bytes, record + 12, length)
}

fn test_font_checksums_sum_unaligned_padded_words_with_wraparound_and_skip_head() {
	mut bytes := []u8{len: 96}
	bytes[5] = 3
	checksum_test_record(mut bytes, 0, 'data', 61, 8)
	checksum_test_record(mut bytes, 1, 'head', 72, 4)
	checksum_test_record(mut bytes, 2, 'odd!', 80, 3)
	for i, value in [u8(255), 255, 255, 255, 0, 0, 0, 2] { bytes[61 + i] = value }
	for i, value in [u8(1), 2, 3, 4] { bytes[72 + i] = value }
	// x.ttf includes the stored padding byte in its whole-word sum.
	for i, value in [u8(1), 2, 3, 4] { bytes[80 + i] = value }
	mut expected := bytes.clone()
	checksum_test_write_u32(mut expected, 16, 1)
	checksum_test_write_u32(mut expected, 48, 0x01020304)
	normalize_table_checksums(mut bytes)
	assert bytes == expected
	// A second normalization changes neither the directory nor table storage.
	normalize_table_checksums(mut bytes)
	assert bytes == expected
}

fn test_font_checksums_leave_out_of_bounds_tables_untouched_and_accept_empty_tables() {
	mut bytes := []u8{len: 88, init: 47}
	bytes[4] = 0
	bytes[5] = 4
	checksum_test_record(mut bytes, 0, 'past', 86, 1)
	checksum_test_record(mut bytes, 1, 'huge', 0xffffffff, 4)
	checksum_test_record(mut bytes, 2, 'long', 80, 0xffffffff)
	checksum_test_record(mut bytes, 3, 'zero', 88, 0)
	mut expected := bytes.clone()
	checksum_test_write_u32(mut expected, 64, 0)
	normalize_table_checksums(mut bytes)
	assert bytes == expected
}

fn test_font_checksums_stop_at_truncated_directory_records() {
	mut bytes := []u8{len: 31, init: 91}
	bytes[4] = 0
	bytes[5] = 2
	checksum_test_record(mut bytes, 0, 'zero', 0, 0)
	mut expected := bytes.clone()
	checksum_test_write_u32(mut expected, 16, 0)
	normalize_table_checksums(mut bytes)
	assert bytes == expected
	mut short_header := [u8(0), 1, 0, 0, 9]
	normalize_table_checksums(mut short_header)
	assert short_header == [u8(0), 1, 0, 0, 9]
}
