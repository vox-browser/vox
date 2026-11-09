module jpegxl

import encoding.hex
import math

fn quant_weight_word(value f32) string {
	return if math.is_nan(value) { 'nan' } else { math.f32_bits(value).str() }
}

fn test_quant_weight_bands_match_source_half_floats_rows_and_positions() {
	mut count := 0
	mut successes := 0
	for line in $embed_file('testdata/quant-bands.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 3
		mut reader := new_bit_reader(hex.decode(f[0])!)
		actual := if params := reader.read_dct_quant_weight_params() {
			successes++
			params.parameters[..].map(it.map(quant_weight_word(it)).join(',')).join(';')
		} else {
			'err'
		}
		assert actual == f[2], 'quantization bands ${count}'
		assert reader.position == f[1].int(), 'quantization band cursor ${count}'
		count++
	}
	assert count == 4096
	assert successes > 500
}

fn test_quant_weight_half_reader_retains_source_nonfinite_classes() {
	for bits in [u16(0x7c00), 0xfc00, 0x7c01, 0xffff] {
		mut reader := new_bit_reader([u8(bits), u8(bits >> 8)])
		value := reader.read_quantization_half()!
		assert reader.position == 16
		if bits & 1023 == 0 {
			assert math.is_inf(value, if bits & 0x8000 == 0 { 1 } else { -1 })
		} else {
			assert math.is_nan(value)
		}
		mut checked := new_bit_reader([u8(bits), u8(bits >> 8)])
		if _ := checked.read_f16() {
			assert false
		}
	}
}

fn test_quant_weight_bands_reject_missing_rows_and_delay_first_weight_validation() {
	// Two bands in the first row: zero initial weight is rejected after both halves.
	mut reader := new_bit_reader([u8(1), 0, 0, 0, 0])
	if _ := reader.read_dct_quant_weight_params() {
		assert false
	}
	assert reader.position == 36
	mut missing := new_bit_reader([]u8{})
	if _ := missing.read_dct_quant_weight_params() {
		assert false
	}
	// One band per row, first positive normal but the second row is truncated.
	mut truncated := new_bit_reader([u8(0), 0xc0, 3])
	if _ := truncated.read_dct_quant_weight_params() {
		assert false
	}
	assert truncated.position == 20
}
