// vtest build: macos
module ggshape

import crypto.sha256

fn test_unblurred_outer_shadow_matches_graphite_coverage_and_compositing() {
	// Pre-migration GPU oracle 59b9b9a5d65da5d69b196474afc5eb48c9e71e21f3fddfc04b986aa9d2a47c54.
	// Transparent and opaque targets, fractional geometry and transformed clips.
	hashes := [
		'55999acd19428ec8d7357b9b8229241d04d05840d7b6a4d50fb875f510740e30',
		'330385369159867044330e5fa55ee0182b332f5a19591588f1ddcfa1f3b92940',
		'e24be7d73dcbb7b95a670ea340d75554d032beb9821b5ace8393d122b87f57c8',
		'9d7b8fa469fda111b3db0846db545e2d1472faa92bb97f454b3c88ce722df1a6',
	]
	mut index := 0
	for matrix in [[f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!, [f32(1.125), 0, 0.375, 0, 0.875, 0.25, 0,
		0, 1]!] {
		for background in [i32(0), 1] {
			shape := C.VoxGraphiteShape{
				matrix:          matrix
				rect:            [f32(2.25), 3.5, 42.5, 24.25, 12, 12, 12, 12, 12, 12, 12, 12]!
				underlay_rect:   [f32(4.75), 5.25, 37, 19, 9.5, 9.5, 9.5, 9.5, 9.5, 9.5, 9.5, 9.5]!
				fill:            9
				anti_alias:      1
				has_float_color: 1
				float_color:     [f32(0.15), 0.4, 0.7, f32(10) / 255]!
			}
			mut pixels := []u8{len: 48 * 32 * 4, init: u8(252)}
			for i in 0 .. 48 * 32 { pixels[i * 4 + 3] = 255 }
			assert draw(pixels.data, 48, 32, 48 * 4, background, &shape) == 1
			assert sha256.sum(pixels).hex() == hashes[index]
			index++
		}
	}
}
