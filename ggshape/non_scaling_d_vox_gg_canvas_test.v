// vtest build: macos && vox_gg_canvas?
module ggshape

import crypto.sha256
import os

#include <dlfcn.h>

fn C.dlopen(path &char, mode i32) voidptr
fn C.dlsym(handle voidptr, symbol &char) voidptr

type NonScalingPathOracle = fn (pixels &u8, width i32, height i32, pitch i32, background i32, path &C.VoxGraphitePath) i32

type NonScalingSvgOracle = fn (pixels &u8, width i32, height i32, pitch i32, flags i32, paths &C.VoxGraphitePath, count i32, parent &f32, viewport &f32, rounded &f32) i32

fn non_scaling_test_pixels() []u8 {
	// Three padding pixels on each row must survive either backend.
	mut pixels := []u8{len: (48 + 3) * 32 * 4, init: 0xa5}
	for y in 0 .. 32 {
		for x in 0 .. 48 {
			i := (y * 51 + x) * 4
			pixels[i] = u8(x * 3)
			pixels[i + 1] = u8(y * 4)
			pixels[i + 2] = 80
			pixels[i + 3] = 200
		}
	}
	return pixels
}

// Both standalone and embedded SVG draws must match the original backend,
// including the effect of parent * matrix * inverse(matrix) rounding.
fn test_non_scaling_strokes_match_graphite_with_clips_and_svg_parents() {
	library := os.join_path(@DIR, '..', 'Build/v/Vox.app/Contents/MacOS/libVoxGraphite.dylib')
	identity := sha256.sum(os.read_bytes(library)!).hex()
	handle := C.dlopen(&char(library.str), 1)
	assert handle != unsafe { nil }
	draw := NonScalingPathOracle(C.dlsym(handle, c'vox_graphite_draw_path_pixels'))
	svg := NonScalingSvgOracle(C.dlsym(handle, c'vox_graphite_draw_svg_image_pixels'))
	assert draw != unsafe { nil }
	assert svg != unsafe { nil }
	mut segments := [f32(0), 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 12, 4, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 3, 24, 18, 15, 0, 22, 26, 0, 0, 0, 0, 0]
	matrices := [
		[f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!,
		[f32(3), 0, 1.5, 0, 2, 0.25, 0, 0, 1]!,
		[f32(-1.25), 0, 35, 0, 0.75, 0.5, 0, 0, 1]!,
		[f32(0), -1.25, 35, 0.75, 0, 0.5, 0, 0, 1]!,
		[f32(0.8660254), -0.5, 20, 0.5, 0.8660254, -6, 0, 0, 1]!,
		[f32(1), 0.3, 0, 0.1, 1, 0, 0, 0, 1]!,
		[f32(0), 0, 15, 0, 1, 2, 0, 0, 1]!,
	]
	parent := [f32(1.125), 0.2, 0.375, -0.125, 0.875, 1.25, 0, 0, 1]!
	viewport := [f32(0), 0, 42, 30]!
	rounded := [f32(1), 1, 44, 28, 3, 3, 3, 3, 3, 3, 3, 3]!
	for matrix in matrices {
		for background in [i32(0), 1] {
			mut path := C.VoxGraphitePath{
				matrix:             matrix
				segments:           segments.data
				segment_count:      3
				red:                35
				green:              167
				blue:               79
				alpha:              200
				stroke:             1
				non_scaling_stroke: 1
				stroke_width:       2.5
				line_join:          1
				line_cap:           2
				miter_limit:        4
				has_clip:           1
				clip:               [f32(1), 1, 28, 26, 4, 4, 4, 4, 4, 4, 4, 4]!
			}
			mut expected := non_scaling_test_pixels()
			mut actual := expected.clone()
			assert draw(expected.data, 48, 32, 51 * 4, background, &path) == 1
			assert draw_path(actual.data, 48, 32, 51 * 4, background, &path) == 1, 'matrix=${matrix} background=${background}'
			assert actual == expected
			for layer in [false, true] {
				clip := if layer { unsafe { &rounded[0] } } else { unsafe { &f32(nil) } }
				expected = non_scaling_test_pixels()
				actual = expected.clone()
				assert svg(expected.data, 48, 32, 51 * 4, background, &path, 1, &parent[0], &viewport[0], clip) == 1
				assert draw_svg_image(actual.data, 48, 32, 51 * 4, background, &path, 1, &parent[0], &viewport[0], clip) == 1, 'matrix=${matrix} background=${background} layer=${layer}'
				assert actual == expected
			}
		}
	}
	assert sha256.sum(os.read_bytes(library)!).hex() == identity, 'oracle library changed during checks'
}

fn test_non_scaling_svg_decline_preserves_the_whole_target() {
	mut segments := [f32(0), 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 12, 4, 0, 0, 0, 0, 0, 0, 0, 0,
		0]
	mut paths := [C.VoxGraphitePath{
		matrix:             [f32(2), 0, 1, 0, 2, 1, 0, 0, 1]!
		segments:           segments.data
		segment_count:      2
		red:                255
		alpha:              255
		stroke:             1
		non_scaling_stroke: 1
		stroke_width:       2
	}, C.VoxGraphitePath{
		matrix:             [f32(2), 0, 1, 0, 2, 1, 0.01, 0, 1]!
		segments:           segments.data
		segment_count:      2
		red:                255
		alpha:              255
		stroke:             1
		non_scaling_stroke: 1
		stroke_width:       2
	}]
	parent := [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
	viewport := [f32(0), 0, 48, 32]!
	mut pixels := non_scaling_test_pixels()
	assert draw_svg_image(pixels.data, 48, 32, 51 * 4, 1, paths.data, 2, &parent[0], &viewport[0], unsafe { nil }) == 0
	assert pixels == non_scaling_test_pixels()
}
