// vtest build: macos
module ggshape

import math
import stbi

fn test_text_gradient_local_coordinates_preserve_clips_and_reject_other_geometry() {
	points := [f32(0), 854, 208, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 932, 287, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	original := points.clone()
	path := C.VoxGraphitePath{
		segments:          points.data
		segment_count:     3
		gradient:          1
		matrix:            [f32(1), 0, -854, 0, 1, -208, 0, 0, 1]!
		gradient_matrix:   [f32(1), 0, 854, 0, 1, 208, 0, 0, 1]!
		has_clip:          1
		clip:              [f32(854), 208, 78, 79, 4, 4, 4, 4, 4, 4, 4, 4]!
		has_ancestor_clip: 1
		ancestor_clip:     [f32(850), 204, 86, 87, 8, 8, 8, 8, 8, 8, 8, 8]!
	}
	mut segments := []f32{}
	draw := localize_linear_gradient_path(path, mut segments) or { panic('translated picture') }
	assert draw.matrix == [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
	assert draw.gradient_matrix == draw.matrix
	assert segments[1..3] == [f32(0), 0] && segments[13..15] == [f32(78), 79]
	assert draw.clip == [f32(0), 0, 78, 79, 4, 4, 4, 4, 4, 4, 4, 4]!
	assert draw.ancestor_clip == [f32(-4), -4, 86, 87, 8, 8, 8, 8, 8, 8, 8, 8]!
	assert points == original
	for mode in 0 .. 8 {
		mut unsupported := path
		mut invalid := points.clone()
		match mode {
			0 { unsupported.gradient = 2 }
			1 { unsupported.matrix[0] = 2 }
			2 { unsupported.matrix[2] = -854.5 }
			3 { unsupported.matrix[5] = f32(math.nan()) }
			4 { unsupported.gradient_matrix[6] = .5 }
			5 { unsupported.segment_count = 129 }
			6 {
				invalid[0] = 2
				unsupported.segments = invalid.data
			}
			else { unsupported.stroke = 1 }
		}
		assert localize_linear_gradient_path(unsupported, mut segments) == none
	}
}

// The reference is an unchanged 78x79 crop at (854,208) of the archived Brave
// page; the mask is the retained glyph input. Solid mask samples isolate the
// gradient from the page backdrop and final A8 blending.
fn test_text_gradient_local_coordinates_match_the_brave_heading() {
	mask_bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/resources/gradient-text-page-mask.png').to_bytes()
	mask := stbi.load_from_memory(mask_bytes.data, mask_bytes.len, desired_channels: 4)!
	defer { mask.free() }
	ref_bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/resources/gradient-text-page-crop.png').to_bytes()
	ref := stbi.load_from_memory(ref_bytes.data, ref_bytes.len, desired_channels: 4)!
	defer { ref.free() }
	assert mask.width == 78 && mask.height == 79 && ref.width == 78 && ref.height == 79
	points := [f32(0), 854, 208, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 932, 208, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 1, 932, 287, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 854, 287, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	stops := [f32(203) / 255, 223 / f32(255), 247 / f32(255), f32(1), .1, 168 / f32(255),
		194 / f32(255), 228 / f32(255), 1, .45, 108 / f32(255), 130 / f32(255), 164 / f32(255),
		1, .9]
	path := C.VoxGraphitePath{
		matrix:          [f32(1), 0, -854, 0, 1, -208, 0, 0, 1]!
		segments:        points.data
		segment_count:   5
		gradient:        1
		gradient_points: [f32(-8.132923), 22.345016, 86.13292, 56.654984, 0, 0]!
		gradient_matrix: [f32(1), 0, 854, 0, 1, 208, 0, 0, 1]!
		stops:           stops.data
		stop_count:      3
		opacity:         1
		gradient_premul: 1
		alpha:           255
	}
	for local in [false, true] {
		mut segments := []f32{}
		draw := if local {
			localize_linear_gradient_path(path, mut segments) or { panic('translated picture') }
		} else {
			path
		}
		mut pixels := []u8{len: 80 * 81 * 4}
		identity := [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
		viewport := [f32(0), 0, 80, 81]!
		assert draw_svg_image(pixels.data, 80, 81, 320, 4, &draw, 1, &identity[0], &viewport[0], unsafe { nil }) == 1
		mut different, mut checked := 0, 0
		for y in 0 .. 79 {
			for x in 0 .. 78 {
				if unsafe { mask.data[(y * 78 + x) * 4 + 3] } != 255 { continue }
				checked++
				mut changed := false
				for c in 0 .. 3 {
					if pixels[(y * 80 + x) * 4 + 2 - c] != unsafe { ref.data[(y * 78 + x) * 4 + c] } {
						changed = true
					}
				}
				if changed { different++ }
			}
		}
		assert checked > 900
		assert different == if local { 0 } else { 1 }
	}
}
