module jpegxl

import encoding.hex
import math

fn test_quantizer_params_match_pinned_source_values_rounding_and_positions() {
	mut count := 0
	for line in $embed_file('testdata/quantizer.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 3
		mut reader := new_bit_reader(hex.decode(f[0])!)
		params := reader.read_quantizer_params()!
		assert reader.position == f[1].int()
		actual := '${params.global_scale},${params.quant_lf},${math.f32_bits(params.inverse_global_scale())},${math.f32_bits(params.inverse_quant_lf())}'
		assert actual == f[2], 'quantizer ${count}'
		count++
	}
	assert count == 4096
}

fn test_quantizer_params_reject_every_byte_prefix_of_longest_encoding() {
	// Both selectors 3 and all payload bits set: global 73,728 and LF 65,536.
	data := [u8(255), 255, 255, 255, 15]
	for length in 0 .. data.len {
		mut reader := new_bit_reader(data[..length])
		if _ := reader.read_quantizer_params() {
			assert false
		}
		assert reader.position <= length * 8
	}
	mut reader := new_bit_reader(data)
	params := reader.read_quantizer_params()!
	assert params.global_scale == 73728
	assert params.quant_lf == 65536
	assert reader.position == 36
}
