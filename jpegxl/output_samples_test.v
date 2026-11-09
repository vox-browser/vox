module jpegxl

import encoding.hex
import math

fn test_output_sample_rows_match_pinned_native_source() {
	mut integers := 0
	mut quantized := 0
	mut premultiplied := 0
	for line in $embed_file('testdata/output-samples.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		match f[0] {
			'I' {
				assert f.len == 5
				storage := if f[1] == '16' {
					ModularStorage.signed16
				} else {
					ModularStorage.signed32
				}
				output := modular_integer_row_to_f32(f[3].split(',').map(it.i32()), f[2].u32(), storage)!
				assert output.map(math.f32_bits(it).str()).join(',') == f[4], 'Integer row ${integers}'
				integers++
			}
			'Q' {
				assert f.len == 7
				input := f[5].split(',').map(math.f32_from_bits(it.u32()))
				output := quantize_output_row(input, f[1].u32(), f[2].u32(), f[3].u32(), f[4].u32())!
				assert hex.encode(output) == f[6], 'Quantized row ${quantized}'
				quantized++
			}
			'P' {
				assert f.len == 5
				input := modular_integer_row_to_f32([]i32{len: 256, init: i32(index)}, 8, .signed32)!
				alpha := modular_integer_row_to_f32([]i32{len: 256, init: f[2].i32()}, 8, .signed32)!
				colors := premultiply_output_row(input, alpha)!
				assert colors.map(math.f32_bits(it).str()).join(',') == f[3], 'Premultiply row ${premultiplied}'
				assert hex.encode(quantize_output_row(colors, 0, f[2].u32(), f[1].u32(), 8)!) == f[4], 'Premultiplied bytes ${premultiplied}'
				premultiplied++
			}
			else {
				assert false, 'Unknown output sample case'
			}
		}
	}
	assert integers == 62 && quantized == 4096 && premultiplied == 768
}

fn test_output_row_bounds_empty_rows_and_dither_wrap() {
	assert modular_integer_row_to_f32([], 8, .signed32)!.len == 0
	assert premultiply_output_row([], [])!.len == 0
	assert quantize_output_row([], 0, 0, 0, 8)!.len == 0
	for bits in [u32(0), 32] {
		if _ := modular_integer_row_to_f32([i32(1)], bits, .signed32) {
			assert false
		}
	}
	for bits in [u32(0), 9] {
		if _ := quantize_output_row([f32(1)], 0, 0, 0, bits) {
			assert false
		}
	}
	if _ := premultiply_output_row([f32(1)], []) {
		assert false
	}
	input := []f32{len: 65, init: f32(0.5)}
	whole := quantize_output_row(input, 4294967295, 4294967295, 4294967295, 8)!
	assert whole == quantize_output_row(input, 31, 31, 31, 8)!
	for offset in [0, 1, 31, 32, 33, 64] {
		assert quantize_output_row(input[offset..], u32(31 + offset), 31, 31, 8)! == whole[offset..]
	}
}
