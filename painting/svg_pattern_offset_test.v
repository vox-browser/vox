module painting

import math

fn test_svg_pattern_offset_projects_crop_and_delta_independently() {
	offset := SVGPatternOffset{Point{4, -2}, Rect{3, 2, 10, 20}}
	projected := offset.transformed(Affine{a: 2, d: 3, e: 10, f: 20}) or {
		panic('expected an axis-aligned projection')
	}
	assert projected.region == Rect{16, 26, 20, 60}
	assert projected.delta == Point{8, -6}
	assert offset.transformed(Affine{b: 1}) == none
	assert offset.transformed(Affine{a: 0}) == none
}

fn test_svg_pattern_offset_turns_both_crop_and_delta() {
	offset := SVGPatternOffset{Point{-2, 5}, Rect{2, 3, 10, 20}}
	projected := offset.transformed(Affine{a: 0, b: 1, c: -1, d: 0, e: 30}) or {
		panic('expected a quarter-turn projection')
	}
	assert projected.region == Rect{7, 2, 20, 10}
	assert projected.delta == Point{-5, -2}
}

fn test_svg_pattern_offset_keeps_an_empty_crop_transparent() {
	offset := SVGPatternOffset{Point{4, -2}, Rect{3, 2, 0, 20}}
	assert offset.transformed(Affine{b: 1})? == SVGPatternOffset{}
}

fn test_svg_pattern_offset_cache_separates_positive_and_negative_offsets() {
	mut keys := map[u64]bool{}
	for dx in -4 .. 6 {
		offset := SVGPatternOffset{Point{f64(dx), 8}, Rect{0, 0, 40, 40}}
		// The filter graph also contributes dx in the existing word-wise hash.
		key := (offset.mix_cache_key(123) ^ math.f64_bits(f64(dx))) * u64(1099511628211)
		assert key !in keys
		keys[key] = true
	}
}
