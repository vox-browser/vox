module jpegxl

import encoding.hex

fn test_hybrid_uint_values_max_bits_and_consumption_match_frozen_source() {
	mut count := 0
	for line in $embed_file('testdata/hybrid-values.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		fields := line.split('\t')
		assert fields.len == 8
		config := HybridUint{
			split_exponent: u32(fields[0].u64())
			msb_in_token:   u32(fields[1].u64())
			lsb_in_token:   u32(fields[2].u64())
		}
		symbol := u32(fields[3].u64())
		mut reader := new_bit_reader(hex.decode(fields[4])!)
		assert config.read(symbol, mut reader)! == u32(fields[6].u64()), line
		assert reader.position == fields[5].int(), line
		assert config.max_bits_for_symbol(symbol) == fields[7].int(), line
		reader.check_end()!
		count++
	}
	assert count == 384
}

fn test_hybrid_uint_invalid_configurations_and_truncation_are_bounded() {
	mut reader := new_bit_reader([]u8{})
	for config in [HybridUint{ split_exponent: 32 }, HybridUint{ split_exponent: 1, msb_in_token: 2 },
		HybridUint{ split_exponent: 1, lsb_in_token: 2 }] {
		if _ := config.read(16, mut reader) {
			assert false
		}
	}
	for alphabet in [-1, 16] {
		if _ := reader.read_hybrid_uint(alphabet) {
			assert false
		}
	}
	config := HybridUint{ split_exponent: 4, msb_in_token: 2 }
	assert config.read(16, mut reader)! == 16
	if _ := reader.check_end() {
		assert false
	}
}
