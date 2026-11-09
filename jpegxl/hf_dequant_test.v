module jpegxl

import crypto.sha256
import encoding.binary
import math

fn hf_fixture_floats(text string) []f32 {
	return text.split(',').map(math.f32_from_bits(it.u32()))
}

fn hf_fixture_matrices(transform HfTransform) !DequantMatrices {
	mut tables := []DequantMatrix{len: 17}
	index := transform.quant_table_index()
	tables[index] = compute_quant_matrix(LibraryQuantEncoding{}, index)!
	return DequantMatrices{ tables: tables }
}

fn test_hf_dequant_matches_complete_source_simd_blocks() {
	mut count := 0
	mut words := 0
	mut transforms := map[int]bool{}
	for line in $embed_file('testdata/hf-dequant.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 16
		transform := hf_transform_from_id(f[0].int())!
		biases := hf_fixture_floats(f[11])
		params := HfDequantParameters{
			transform: transform
			storage: if f[1] == '16' { ModularStorage.signed16 } else { ModularStorage.signed32 }
			quantizer: QuantizerParams{ global_scale: f[2].u32() }
			raw_quant: f[3].u32()
			x_qm_scale: f[4].u32()
			b_qm_scale: f[5].u32()
			color_correlation: ColorCorrelationParams{
				color_factor: f[6].u32()
				base_correlation_x: math.f32_from_bits(f[7].u32())
				base_correlation_b: math.f32_from_bits(f[8].u32())
			}
			x_color_factor: i32(f[9].i64())
			b_color_factor: i32(f[10].i64())
			biases: [biases[0], biases[1], biases[2], biases[3]]!
		}
		coefficients := [f[12].split(',').map(i32(it.i64())),
			f[13].split(',').map(i32(it.i64())), f[14].split(',').map(i32(it.i64()))]!
		before := coefficients[0].clone()
		actual := dequantize_hf_block(coefficients, hf_fixture_matrices(transform)!, params)!
		assert coefficients[0] == before
		num := coefficients[0].len
		mut data := []u8{len: 3 * num * 4}
		for c in 0 .. 3 {
			assert actual[c].len == num
			for k, value in actual[c] {
				binary.little_endian_put_u32_at(mut data, math.f32_bits(value), (c * num + k) * 4)
			}
		}
		assert sha256.sum(data).hex() == f[15], 'HF block ${count}'
		transforms[int(transform)] = true
		words += 3 * num
		count++
	}
	assert count == 512
	assert transforms.len == 27
	assert words == 1930368
}

fn test_hf_dequant_rejects_invalid_metadata_and_storage() {
	matrices := hf_fixture_matrices(.dct)!
	params := HfDequantParameters{
		storage: .signed32
		quantizer: QuantizerParams{ global_scale: 65536 }
		raw_quant: 1
		x_qm_scale: 2
		b_qm_scale: 2
		biases: default_opsin().quant_biases
	}
	coefficients := [ []i32{len: 64}, []i32{len: 64}, []i32{len: 64} ]!
	dequantize_hf_block(coefficients, matrices, params)!
	for invalid in [HfDequantParameters{ ...params, raw_quant: 0 },
		HfDequantParameters{ ...params, x_qm_scale: 8 },
		HfDequantParameters{ ...params, b_qm_scale: 8 },
		HfDequantParameters{ ...params, quantizer: QuantizerParams{} },
		HfDequantParameters{ ...params, quantizer: QuantizerParams{ global_scale: 73729 } },
		HfDequantParameters{ ...params, color_correlation: ColorCorrelationParams{ color_factor: 0 } },
		HfDequantParameters{ ...params, color_correlation: ColorCorrelationParams{ base_correlation_x: 5 } },
		HfDequantParameters{ ...params, x_color_factor: -129 },
		HfDequantParameters{ ...params, b_color_factor: 128 },
		HfDequantParameters{ ...params, biases: [math.f32_from_bits(0x7f800000), f32(1), f32(1), f32(0)]! }] {
		if _ := dequantize_hf_block(coefficients, matrices, invalid) { assert false }
	}
	if _ := dequantize_hf_block([[]i32{}, coefficients[1], coefficients[2]]!, matrices, params) { assert false }
	if _ := dequantize_hf_block(coefficients, DequantMatrices{}, params) { assert false }
	mut tables := matrices.tables.clone()
	tables[0] = DequantMatrix{ rows: 8, columns: 8, samples: []f32{len: 192} }
	if _ := dequantize_hf_block(coefficients, DequantMatrices{ tables: tables }, params) { assert false }
}
