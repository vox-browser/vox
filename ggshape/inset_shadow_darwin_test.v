// vtest build: macos
module ggshape

import stbi

fn test_unblurred_inset_drrect_matches_brave_inside_rounded_clip() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/unblurred-inset-shadow.png').to_bytes()
	ref := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic('ref') }
	defer { ref.free() }
	bg := C.VoxGraphiteShape{
		matrix:     [f32(1), 0, 0, 0, 1, -254, 0, 0, 1]!
		rect:       [
			f32(359.5),
			261.5,
			203,
			31,
			5.5,
			5.5,
			5.5,
			5.5,
			5.5,
			5.5,
			5.5,
			5.5,
		]!
		fill:       1
		anti_alias: 1
		force_msaa: 0
		red:        255
		green:      255
		blue:       255
		alpha:      255
	}
	shadow := C.VoxGraphiteShape{
		matrix:                bg.matrix
		rect:                  [f32(360), 262, 202, 31, 0, 0, 0, 0, 0, 0, 0, 0]!
		underlay_rect:         [f32(360), 263, 202, 30, 5, 5, 5, 5, 5, 5, 5, 5]!
		contour_reference:     [
			f32(360),
			262,
			202,
			30,
			5,
			5,
			5,
			5,
			5,
			5,
			5,
			5,
		]!
		has_contour_reference: 1
		fill:                  14
		anti_alias:            1
		force_msaa:            0
		has_float_color:       1
		float_color:           [
			f32(31) / 255,
			f32(35) / 255,
			f32(40) / 255,
			f32(10) / 255,
		]!
	}
	border := C.VoxGraphiteShape{ ...bg, fill: 0, thickness: 1, red: 209, green: 217, blue: 224 }
	shapes := [bg, shadow, border]
	for grouped in [false, true] {
		mut pixels := []u8{len: 1024 * 256 * 4, init: 255}
		if grouped {
			assert draw_shapes(pixels.data, 1024, 256, 4096, 1, shapes.data, 3) == 1
		} else {
			for shape in shapes {
				assert draw(pixels.data, 1024, 256, 4096, 1, &shape) == 1
			}
		}
		mut n := 0
		for y in 0 .. 46 {
			for x in 350 .. 567 {
				i := (y * 1024 + x) * 4
				j := ((y + 254) * 1024 + x) * 4
				mut d := false
				for c in 0 .. 4 {
					ch := if c == 0 {
						2
					} else if c == 2 {
						0
					} else {
						c
					}
					if pixels[i + ch] != unsafe { ref.data[j + c] } { d = true }
				}
				if d { n++ }
			}
		}
		assert n == 0, 'inset differences=${n}, grouped=${grouped}'
	}
}

fn test_unsupported_inset_blur_or_missing_content_clip_preserves_backdrop() {
	for shape in [
		C.VoxGraphiteShape{ fill: 14, thickness: 1, has_contour_reference: 1 },
		C.VoxGraphiteShape{ fill: 14 },
	] {
		mut pixels := []u8{len: 16 * 16 * 4, init: 123}
		assert draw(pixels.data, 16, 16, 64, 1, &shape) == 0
		assert pixels.all(it == 123)
	}
}
