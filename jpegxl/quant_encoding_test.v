module jpegxl

import encoding.hex
import math

fn quant_encoding_word(value f32) string {
	return if math.is_nan(value) { 'nan' } else { math.f32_bits(value).str() }
}

fn quant_encoding_rows(rows [3][]f32) string {
	return rows[..].map(it.map(quant_encoding_word(it)).join(',')).join(';')
}

fn quant_encoding_bands(parameters DctQuantWeightParams) string {
	return quant_encoding_rows(parameters.parameters)
}

fn nonraw_quant_text(q NonRawQuantEncoding) string {
	return match q {
		LibraryQuantEncoding { 'library' }
		IdentityQuantEncoding { 'identity|${quant_encoding_rows(q.weights)}' }
		Dct2QuantEncoding { 'dct2|${quant_encoding_rows(q.weights)}' }
		Dct4QuantEncoding {
			'dct4|${quant_encoding_rows(q.multipliers)}|${quant_encoding_bands(q.parameters)}'
		}
		Dct4x8QuantEncoding {
			'dct4x8|${quant_encoding_rows(q.multipliers)}|${quant_encoding_bands(q.parameters)}'
		}
		AfvQuantEncoding {
			'afv|${quant_encoding_rows(q.weights)}|${quant_encoding_bands(q.parameters4x8)}|${quant_encoding_bands(q.parameters4x4)}'
		}
		DctQuantEncoding { 'dct|${quant_encoding_bands(q.parameters)}' }
	}
}

fn test_nonraw_quant_encodings_match_source_modes_table_shapes_and_positions() {
	mut count := 0
	mut modes := map[string]int{}
	for line in $embed_file('testdata/quant-encoding.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 5
		blocks := quant_table_blocks(f[0].int())!
		assert '${blocks[0]},${blocks[1]}' == f[2]
		mut reader := new_bit_reader(hex.decode(f[1])!)
		actual := if q := reader.read_nonraw_quant_encoding(f[0].int()) {
			nonraw_quant_text(q)
		} else {
			'err'
		}
		assert actual == f[4], 'non-raw quantization ${count}'
		assert reader.position == f[3].int(), 'quantization encoding cursor ${count}'
		if actual != 'err' { modes[actual.split('|')[0]]++ }
		count++
	}
	assert count == 4096
	assert modes.len == 7
	for mode in ['library', 'identity', 'dct2', 'dct4', 'dct4x8', 'afv', 'dct'] {
		assert modes[mode] > 10
	}
}

fn test_nonraw_quant_encodings_reject_bounds_raw_mode_and_missing_payloads() {
	for index in [-1, 17] {
		mut reader := new_bit_reader([u8(0)])
		if _ := reader.read_nonraw_quant_encoding(index) {
			assert false
		}
		assert reader.position == 0
	}
	mut raw := new_bit_reader([u8(7)])
	if _ := raw.read_nonraw_quant_encoding(0) {
		assert false
	}
	assert raw.position == 3
	for mode in [u8(1), 2, 3, 4, 5] {
		mut reader := new_bit_reader([mode])
		if _ := reader.read_nonraw_quant_encoding(4) {
			assert false
		}
		assert reader.position == 3
	}
	mut missing := new_bit_reader([]u8{})
	if _ := missing.read_nonraw_quant_encoding(0) {
		assert false
	}
	mut truncated := new_bit_reader([u8(6)])
	if _ := truncated.read_nonraw_quant_encoding(0) {
		assert false
	}
	assert truncated.position == 7
}
