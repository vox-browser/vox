module jpegxl

import math

fn test_spline_cosine_and_erf_profiles_match_native_float_words() {
	mut count := 0
	mut differing := 0
	mut signs := [2]bool{}
	for line in $embed_file('testdata/spline-math.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t').map(it.u32())
		x := math.f32_from_bits(f[0])
		assert math.is_finite(x)
		assert math.f32_bits(spline_fast_cos(x)) == f[1], 'Spline cosine input ${f[0]}'
		scalar := math.f32_bits(spline_fast_erf(x, false))
		assert scalar == f[2] && scalar == f[3], 'Spline scalar erf input ${f[0]}'
		assert math.f32_bits(spline_fast_erf(x, true)) == f[4], 'Spline fused erf input ${f[0]}'
		if f[2] != f[4] { differing++ }
		if f[0] == 0 {
			signs[0] = true
			assert scalar == 0
		}
		if f[0] == 0x80000000 {
			signs[1] = true
			assert scalar == 0x80000000
		}
		count++
	}
	assert count == 14361 && differing == 135 && signs[..].all(it)
}
