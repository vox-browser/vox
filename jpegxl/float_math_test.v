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

// all_finite tests exponent bits; it must agree with math.is_finite for every
// class of f32, alone and at each position of a longer vectorized run.
fn test_all_finite_matches_is_finite_for_special_values() {
	specials := [u32(0), 0x80000000, 1, 0x80000001, 0x007fffff, 0x00800000, 0x3f800000, 0xbf800000,
		0x7f7fffff, 0xff7fffff, 0x7f800000, 0xff800000, 0x7f800001, 0xff800001, 0x7fc00000, 0xffc00000,
		0x7fffffff, 0xffffffff, 0x7fbfffff]
	for bits in specials {
		value := math.f32_from_bits(bits)
		assert all_finite([value]) == math.is_finite(value), 'bits ${bits:08x}'
		for length in [5, 16, 37] {
			for position in 0 .. length {
				mut values := []f32{len: length, init: f32(index) * 0.5}
				values[position] = value
				assert all_finite(values) == math.is_finite(value)
			}
		}
	}
	assert all_finite([]f32{})
}
