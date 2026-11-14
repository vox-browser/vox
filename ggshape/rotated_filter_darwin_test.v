// vtest build: macos
module ggshape

import math
import stbi

fn translucent_rotated_filter_shape() C.VoxGraphiteShape {
	a := -24.0 * math.pi / 180.0
	c, s := math.cos(a), math.sin(a)
	return C.VoxGraphiteShape{
		matrix:          [f32(c), f32(-s), f32(200 - c * 120 + s * 60), f32(s), f32(c),
			f32(140 - s * 120 - c * 60), 0, 0, 1]!
		rect:            [f32(0), -15, 240, 120, 120, 60, 120, 60, 120, 60, 120, 60]!
		underlay_rect:   [f32(0), 0, 240, 120, 120, 60, 120, 60, 120, 60, 120, 60]!
		fill:            10
		thickness:       60
		anti_alias:      1
		has_float_color: 1
		float_color:     [f32(121) / 255, f32(168) / 255, f32(243) / 255, f32(9) / 255]!
		has_filter_clip: 1
		filter_clip:     [f32(0), 0, 400, 320]!
	}
}

fn test_translucent_rotated_filter_matches_brave_in_the_document_tiles() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/rotated-translucent-shadow.png').to_bytes()
	ref := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic('reference') }
	defer { ref.free() }
	for samples in [i32(0), 1] {
		mut different := 0
		for row in 0 .. 2 {
			y0 := row * 254
			base := translucent_rotated_filter_shape()
			mut shape := C.VoxGraphiteShape{ ...base, force_msaa: samples }
			shape.matrix[5] -= f32(y0)
			shape.filter_clip[1] -= f32(y0)
			shape.filter_clip[3] -= f32(y0)
			mut pixels := []u8{len: 416 * 256 * 4}
			for i in 0 .. 416 * 256 {
				pixels[i * 4] = 15
				pixels[i * 4 + 1] = 11
				pixels[i * 4 + 2] = 9
				pixels[i * 4 + 3] = 255
			}
			assert draw(pixels.data, 416, 256, 1664, 1, &shape) == 1
			for y in if row == 0 { 0 } else { 1 } .. if row == 0 { 255 } else { 26 } {
				// The lower SVG only establishes tile MSAA in the browser fixture.
				// This check covers the shadow and hole through document row 279.
				for x in 0 .. 400 {
					for c in 0 .. 4 {
						ch := if c == 0 {
							2
						} else if c == 2 {
							0
						} else {
							c
						}
						if pixels[(y * 416 + x) * 4 + ch] != unsafe { ref.data[((y + y0) * 400 + x) * 4 + c] } {
							different++
						}
					}
				}
			}
		}
		assert different == 0, 'samples=${samples} differing channels=${different}'
	}
}

fn test_rotated_filter_keeps_opaque_circular_and_unsupported_paints_on_replay() {
	base := translucent_rotated_filter_shape()
	assert rotated_filter_supported(&base)
	for shape in [C.VoxGraphiteShape{ ...base, fill: 9 }, C.VoxGraphiteShape{ ...base, anti_alias: 0 },
		C.VoxGraphiteShape{ ...base, float_color: [f32(0), 0, 0, 1]! },
		C.VoxGraphiteShape{ ...base, float_color: [f32(0), 0, 0, 0]! },
		C.VoxGraphiteShape{ ...base, float_color: [f32(0), 0, 0, f32(math.nan())]! },
		C.VoxGraphiteShape{ ...base, matrix: [f32(1), .1, 0, 0, 1, 0, 0, 0, 1]! },
		C.VoxGraphiteShape{ ...base, matrix: [f32(0), -1, 240, 1, 0, 0, 0, 0, 1]! },
		C.VoxGraphiteShape{ ...base, rect: [f32(0), 0, 120, 120, 60, 60, 60, 60, 60, 60, 60, 60]! }] {
		assert !rotated_filter_supported(&shape)
	}
}

fn test_rotated_filter_rejects_empty_invalid_and_unbounded_layer_requests() {
	base := translucent_rotated_filter_shape()
	for shape in [base, C.VoxGraphiteShape{ ...base, filter_clip: [f32(0), 0, f32(math.nan()),
		320]! }, C.VoxGraphiteShape{ ...base, filter_clip: [f32(20), 20, 10, 10]! }] {
		if _ := rotated_shadow_filter_layer(&shape, 0, 320) {
			assert false
		}
		if _ := rotated_shadow_filter_layer(&shape, 400, 0) {
			assert false
		}
	}
	for clip in [[f32(0), 0, f32(math.nan()), 320]!, [f32(20), 20, 10, 10]!] {
		shape := C.VoxGraphiteShape{ ...base, filter_clip: clip }
		if _ := rotated_shadow_filter_layer(&shape, 400, 320) {
			assert false
		}
	}
	large := C.VoxGraphiteShape{
		...base
		has_filter_clip: 0
		rect:            [f32(0), 0, 10000, 1000, 5000, 500, 5000, 500, 5000, 500, 5000, 500]!
	}
	if _ := rotated_shadow_filter_layer(&large, 16384, 16384) {
		assert false
	}
}
