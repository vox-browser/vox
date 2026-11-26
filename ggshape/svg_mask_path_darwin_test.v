// vtest build: macos
module ggshape

import crypto.sha256
import svg

#include "@DIR/svg_mask_path_test.h"

fn C.vox_test_mask_path(pixels &u8, size int, segments &f32, count int, x f32, y f32,
	scale f32, stroke int, clipped int) int

@[export: 'vox_test_mask_raster']
fn mask_raster_callback(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	path &C.VoxGraphitePath) i32 {
	// These neutral-color paths have identical RGBA and BGRA channel order.
	return draw_path(pixels, width, height, pitch, backdrop, path)
}

fn mask_test_segments(input string) []f32 {
	mut result := []f32{}
	mut x, mut y := f32(0), f32(0)
	for instruction in svg.parse_path_data(input).to_absolute().instructions {
		mut segment := []f32{len: 12}
		d := instruction.data
		match instruction.type_ {
			.move, .line {
				segment[0] = if instruction.type_ == .move { f32(0) } else { f32(1) }
				x = f32(d[0])
				y = f32(d[1])
			}
			.horizontal_line {
				segment[0] = 1
				x = f32(d[0])
			}
			.vertical_line {
				segment[0] = 1
				y = f32(d[0])
			}
			.curve {
				segment[0] = 3
				x = f32(d[4])
				y = f32(d[5])
				for i in 0 .. 4 { segment[i + 3] = f32(d[i]) }
			}
			.close_path { segment[0] = 5 }
			else { panic('unexpected instruction in mask fixture') }
		}
		segment[1] = x
		segment[2] = y
		result << segment
	}
	return result
}

fn test_solid_mask_paths_match_brave_samples() {
	icon := $embed_file('@VMODROOT/Tests/Browser/Brave/sites/cnn/bodies/7e6e0f4d89a905891b21e5e5cf3fde0a14ac27a2aaae92dad9483eb8bf2f41a2').to_string()
	inputs := [icon.all_after(' d="').all_before('"'), icon.all_after(' d="').all_before('"'),
		'M16 2 C34 2 34 30 16 30 C-2 30 -2 2 16 2 Z M16 10 C8 10 8 22 16 22 C24 22 24 10 16 10 Z',
		'M3 25 C3 1 29 1 29 25']
	positions := [[f32(19), 12, 1], [f32(4), 9, 2], [f32(6), 10, 1], [f32(6), 9, 1]]
	// CSS masks rasterize in their own pixel grid before placement.
	// Independent 48x48 RGBA crops of svg-mask-solid-coverage.png, captured
	// twice in Brave 157.1.99.57 at scale 1 (both captures pixel-identical).
	expected := [
		'61ffb8bb8d529ffe90b84b90f1133d1d94918531bf195cc312a58f287d948890',
		'67de2ef85c5ab6c04bece9854d7d80d7127bda5ed5d0668329e6c5dec992602f',
		'c5fd182bb37dc892f02fec8201baa085f988525233081ac999cc0b14440126d3',
		'a7e683f99c86e399b67b97bb36624e5f804721111fa120f375576289ac0c8600',
	]
	for i, input in inputs {
		segments := mask_test_segments(input)
		mut pixels := []u8{len: 48 * 48 * 4}
		p := positions[i]
		assert C.vox_test_mask_path(pixels.data, 48, segments.data, segments.len / 12,
			p[0], p[1], p[2], int(i == 3), 0) == 1
		assert sha256.sum(pixels).hex() == expected[i], 'mask case ${i}'
	}
}

fn test_mask_upload_preserves_parent_clip_and_opacity() {
	segments := mask_test_segments('M0 0 L48 0 L48 48 L0 48 Z')
	mut pixels := []u8{len: 48 * 48 * 4}
	assert C.vox_test_mask_path(pixels.data, 48, segments.data, segments.len / 12,
		0, 0, 1, 0, 1) == 1
	for y in 0 .. 48 {
		for x in 0 .. 48 {
			i := (y * 48 + x) * 4
			assert pixels[i..i + 4] == if x < 24 {
				[u8(133), 133, 133, 255]
			} else {
				[u8(255), 255, 255, 255]
			}
		}
	}
}
