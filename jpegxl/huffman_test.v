module jpegxl

import encoding.hex

fn huffman_sequence(mut reader BitReader) !string {
	codes := reader.read_huffman_codes(1)!
	mut output := []string{cap: 16}
	for _ in 0 .. 16 { output << codes.read(0, mut reader)!.str() }
	reader.check_end()!
	return output.join(',')
}

fn test_huffman_codes_match_frozen_source_parse_and_symbol_results() {
	mut count := 0
	mut decoded := 0
	for line in $embed_file('testdata/huffman.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		fields := line.split('\t')
		assert fields.len == 4
		mut reader := new_bit_reader(hex.decode(fields[1])!)
		result := huffman_sequence(mut reader) or { 'err' }
		assert result == fields[3], line
		assert reader.position == fields[2].int(), line
		if result != 'err' { decoded++ }
		count++
	}
	assert count == 4096
	assert decoded > 1000
}

fn test_byte_histogram_decodes_original_known_symbol_sequence() {
	mut header := new_bit_reader([u8(0xef), 0x3f, 0, 1, 0, 0xa0, 6])
	codes := header.read_huffman_codes(1)!
	assert codes.max_symbol_for_cluster(0)! == 255
	assert codes.single_symbol(0) == none
	// Each byte is the reverse-bit canonical code for its expected symbol.
	mut stream := new_bit_reader([u8(0x10), 0xb0, 0xa8, 0x44, 0xec, 0x9a, 9, 0x97])
	for expected in [u32(8), 13, 21, 34, 55, 89, 144, 233] {
		assert codes.read(0, mut stream)! == expected
	}
	assert stream.position == 64
	stream.check_end()!
	if _ := codes.read(1, mut stream) {
		assert false
	}
	if _ := codes.max_symbol_for_cluster(-1) {
		assert false
	}
}

fn test_long_codes_cross_primary_table_and_preserve_zero_bit_single_symbols() {
	lengths := [u8(1), 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 15]
	table := build_huffman(lengths)!
	mut serialized := []u8{}
	mut position := 0
	for code in ['0', '10', '110', '1110', '11110', '111110', '1111110', '11111110', '111111110',
		'1111111110', '11111111110', '111111111110', '1111111111110', '11111111111110',
		'111111111111110', '111111111111111'] {
		for bit in code {
			if position % 8 == 0 { serialized << u8(0) }
			serialized[position / 8] |= (bit - `0`) << (position % 8)
			position++
		}
	}
	mut reader := new_bit_reader(serialized)
	for symbol in 0 .. 16 {
		assert table.read(mut reader)! == u32(symbol)
	}
	assert reader.position == position
	reader.check_end()!
	mut empty_stream := new_bit_reader([]u8{})
	single := build_huffman([u8(0), 0, 15])!
	assert single.read(mut empty_stream)! == 2
	assert empty_stream.position == 0
	if _ := table.read(mut empty_stream) {
		if _ := empty_stream.check_end() {
			assert false
		}
	}
}

fn test_malformed_huffman_tables_and_context_counts_are_rejected() {
	for lengths in [[]u8{}, [u8(0), 0], [u8(16)], [u8(1), 1, 1], [u8(2), 2]] {
		if _ := build_huffman(lengths) {
			assert false
		}
	}
	mut empty := new_bit_reader([]u8{})
	for size in [0, 32768, -1] {
		if _ := empty.read_huffman_table(size) {
			assert false
		}
	}
	for count in [0, 65537, -1] {
		if _ := empty.read_huffman_codes(count) {
			assert false
		}
	}
	// Simple table: two duplicate zero symbols from a two-symbol alphabet.
	mut duplicate := new_bit_reader([u8(5)])
	if _ := duplicate.read_huffman_table(2) {
		assert false
	}
	// A single-symbol alphabet consumes only its size varint, then zero bits per symbol.
	mut one := new_bit_reader([u8(0)])
	codes := one.read_huffman_codes(1)!
	assert codes.single_symbol(0)? == 0
	assert codes.read(0, mut one)! == 0
	assert one.position == 1
}

fn test_huffman_reads_all_alphabet_sizes_before_source_validation() {
	// The first alphabet is oversized; the source still reads the second size.
	mut input := new_bit_reader([u8(0xfd), 0xff, 7])
	if _ := input.read_huffman_codes(2) {
		assert false
	}
	assert input.position == 20
}
