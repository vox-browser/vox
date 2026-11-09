module jpegxl

import crypto.sha256
import encoding.binary
import math

fn matrix_fixture_rows(text string) [3][]f32 {
	rows := text.split(';')
	assert rows.len == 3
	return [rows[0].split(',').map(math.f32_from_bits(it.u32())),
		rows[1].split(',').map(math.f32_from_bits(it.u32())),
		rows[2].split(',').map(math.f32_from_bits(it.u32()))]!
}

fn matrix_fixture_bands(text string) DctQuantWeightParams {
	return DctQuantWeightParams{ parameters: matrix_fixture_rows(text) }
}

fn matrix_fixture_encoding(text string) !NonRawQuantEncoding {
	f := text.split('|')
	match f[0] {
		'library' { return LibraryQuantEncoding{} }
		'identity' { return IdentityQuantEncoding{ weights: matrix_fixture_rows(f[1]) } }
		'dct2' { return Dct2QuantEncoding{ weights: matrix_fixture_rows(f[1]) } }
		'dct4' {
			return Dct4QuantEncoding{ multipliers: matrix_fixture_rows(f[1]), parameters: matrix_fixture_bands(f[2]) }
		}
		'dct4x8' {
			return Dct4x8QuantEncoding{ multipliers: matrix_fixture_rows(f[1]), parameters: matrix_fixture_bands(f[2]) }
		}
		'afv' {
			return AfvQuantEncoding{ weights: matrix_fixture_rows(f[1]), parameters4x8: matrix_fixture_bands(f[2]), parameters4x4: matrix_fixture_bands(f[3]) }
		}
		'dct' { return DctQuantEncoding{ parameters: matrix_fixture_bands(f[1]) } }
		else { return error('Unknown matrix fixture encoding') }
	}
}

fn matrix_fixture_result(index int, text string) !string {
	f := text.split('|')
	matrix := if f[0] == 'raw' {
		raw_quant_matrix(index, f[2].split(',').map(i32(it.i64())), math.f32_from_bits(f[1].u32()))!
	} else {
		compute_quant_matrix(matrix_fixture_encoding(text)!, index)!
	}
	assert matrix.samples.len == 3 * matrix.rows * matrix.columns
	mut words := []u8{len: matrix.samples.len * 4}
	for i, value in matrix.samples {
		binary.little_endian_put_u32_at(mut words, math.f32_bits(value), i * 4)
	}
	return '${matrix.rows},${matrix.columns}|${sha256.sum(words).hex()}'
}

fn test_quantization_matrices_match_every_source_word_for_library_custom_and_raw() {
	mut count := 0
	mut successes := 0
	for line in $embed_file('testdata/quant-matrices.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 4
		actual := matrix_fixture_result(f[0].int(), f[1]) or { 'err' }
		expected := if f[3] == 'err' { 'err' } else { '${f[2]}|${f[3]}' }
		assert actual == expected, 'quantization matrix ${count}, index ${f[0]}'
		if actual != 'err' { successes++ }
		count++
	}
	assert count == 1024
	assert successes > 300
}

fn test_quantization_matrix_bounds_storage_and_inclusive_weight_limits() {
	for index in [-1, 17] {
		if _ := library_quant_encoding(index) {
			assert false
		}
		if _ := compute_quant_matrix(LibraryQuantEncoding{}, index) {
			assert false
		}
		if _ := raw_quant_matrix(index, [], 1) {
			assert false
		}
	}
	if _ := raw_quant_matrix(0, [i32(1)], 1) {
		assert false
	}
	if _ := compute_quant_matrix(DctQuantEncoding{}, 0) {
		assert false
	}
	if _ := compute_quant_matrix(IdentityQuantEncoding{}, 0) {
		assert false
	}
	if _ := compute_quant_matrix(library_quant_encoding(1)!, 4) {
		assert false
	}
	for weight in [f32(1e-8), f32(1) / f32(1e-8)] {
		rows := [[]f32{len: 3, init: weight}, []f32{len: 3, init: weight}, []f32{len: 3, init: weight}]!
		assert compute_quant_matrix(IdentityQuantEncoding{ weights: rows }, 0)!.samples.len == 192
	}
	for weight in [f32(0), f32(-1), f32(math.inf(1)), f32(math.nan())] {
		rows := [[]f32{len: 3, init: weight}, []f32{len: 3, init: weight}, []f32{len: 3, init: weight}]!
		if _ := compute_quant_matrix(IdentityQuantEncoding{ weights: rows }, 0) {
			assert false
		}
	}
}
