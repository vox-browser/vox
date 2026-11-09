module jpegxl

import math

fn test_fused_binary32_matches_independent_reference() {
	mut count := 0
	for line in $embed_file('testdata/float-fma.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 4
		a := math.f32_from_bits(f[0].u32())
		b := math.f32_from_bits(f[1].u32())
		c := math.f32_from_bits(f[2].u32())
		result := fused_f32(a, b, c)
		if f[3] == 'nan' {
			assert math.is_nan(result)
		} else {
			assert math.f32_bits(result) == f[3].u32(), 'FMA ${count}'
		}
		if math.is_finite(a) && math.is_finite(b) && math.is_finite(c) {
			assert math.f32_bits(fused_f32_exact(a, b, c)) == f[3].u32(), 'Exact FMA ${count}'
		}
		count++
	}
	assert count == 35008
}
