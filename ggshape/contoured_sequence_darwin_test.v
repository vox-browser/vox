// vtest build: macos
module ggshape

import crypto.sha256

fn test_contour_shadows_and_border_share_their_sample_coverage() {
	// Independent retained Chromium contour picture replayed in one Graphite
	// pass (59b9b9a5d65da5d69b196474afc5eb48c9e71e21f3fddfc04b986aa9d2a47c54).
	reference := [f32(544), 912, 1480, 104, 52, 52, 52, 52, 52, 52, 52, 52]!
	cutout := [f32(545), 913, 1478, 102, 51, 51, 51, 51, 51, 51, 51, 51]!
	rects := [[f32(528), 904, 1512, 136, 68, 68, 68, 68, 68, 68, 68, 68]!,
		[f32(544), 916, 1480, 104, 52, 52, 52, 52, 52, 52, 52, 52]!,
		[f32(542), 910, 1484, 108, 54, 54, 54, 54, 54, 54, 54, 54]!, cutout]
	mut shapes := []C.VoxGraphiteShape{}
	for i, rect in rects {
		shapes << C.VoxGraphiteShape{
			matrix:                [f32(1), 0, 0, 0, 1, -204, 0, 0, 1]!
			rect:                  rect
			contour_parameters:    [f32(1.1), 1.1, 1.1, 1.1]!
			contour_reference:     reference
			has_contour_reference: 1
			anti_alias:            1
			force_msaa:            1
			fill:                  if i == 3 { 12 } else { 13 }
			thickness:             [f32(160), 16, 0, 2][i]
			has_float_color:       1
			float_color:           [f32(0), 0, 0, f32([6, 10, 10, 26][i]) * (f32(1) / 255)]!
			underlay_rect:         if i == 3 {
				[f32(546), 914, 1476, 100, 50, 50, 50, 50, 50, 50, 50, 50]!
			} else {
				cutout
			}
			has_underlay:          if i == 3 { 1 } else { 0 }
			underlay_rgba:         [u8(255), 255, 255, 255]!
		}
	}
	mut pixels := []u8{len: 2048 * 1536 * 4, init: u8(252)}
	for i in 0 .. 2048 * 1536 { pixels[i * 4 + 3] = 255 }
	assert draw_shapes(pixels.data, 2048, 1536, 2048 * 4, 1, shapes.data, 4) == 1
	assert sha256.sum(pixels).hex() == 'df39aa563f77235260ef8b6d3665ddef5cf7f546d0e3fc5cfb7b4d720a2a34fd'
}
