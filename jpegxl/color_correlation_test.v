module jpegxl

import encoding.hex
import math

fn test_color_correlation_matches_pinned_source_float_words_and_positions() {
	mut count := 0
	mut successes := 0
	for line in $embed_file('testdata/color-correlation.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 5
		mut reader := new_bit_reader(hex.decode(f[0])!)
		actual := if c := reader.read_color_correlation_params() {
			successes++
			'${c.color_factor},${math.f32_bits(c.base_correlation_x)},${math.f32_bits(c.base_correlation_b)},${c.ytox_lf},${c.ytob_lf},${math.f32_bits(c.y_to_x_lf())},${math.f32_bits(c.y_to_b_lf())},${math.f32_bits(c.y_to_x(i32(f[1].i64())))},${math.f32_bits(c.y_to_b(i32(f[2].i64())))}'
		} else {
			'err'
		}
		assert actual == f[4], 'color correlation ${count}'
		assert reader.position == f[3].int()
		count++
	}
	assert count == 4096
	assert successes == 2525
}

fn test_color_correlation_half_validation_consumes_both_fields() {
	// Selector 0, X infinity and B zero occupy 35 bits before the error.
	data := hex.decode('00e0030000000000')!
	mut reader := new_bit_reader(data)
	if _ := reader.read_color_correlation_params() {
		assert false
	}
	assert reader.position == 35
	// Source subnormal behavior and both signed zeros are preserved by the shared helper.
	assert math.f32_bits(finite_half_float(1)!) == 0x33000000
	assert math.f32_bits(finite_half_float(0x8000)!) == 0x80000000
}

fn test_color_correlation_rejects_truncated_longest_header() {
	// Selector 3, maximum factor, zero base correlations and signed -128 LF factors.
	complete := hex.decode('feff07000000000000')!
	for length in 0 .. complete.len {
		mut reader := new_bit_reader(complete[..length])
		if _ := reader.read_color_correlation_params() {
			assert false
		}
		assert reader.position <= length * 8
	}
	mut reader := new_bit_reader(complete)
	params := reader.read_color_correlation_params()!
	assert params.color_factor == 65793
	assert params.ytox_lf == -128 && params.ytob_lf == -128
	assert reader.position == 67
}
