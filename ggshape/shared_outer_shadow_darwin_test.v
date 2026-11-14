// vtest build: macos
module ggshape

import stbi

fn test_shadow_background_and_border_keep_corner_samples_until_one_resolve() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/rounded-opaque-shadow-group.png').to_bytes()
	ref := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic('reference') }
	defer { ref.free() }
	shadow := C.VoxGraphiteShape{
		matrix:          [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
		rect:            [f32(551), 189, 86, 28, 6, 6, 6, 6, 6, 6, 6, 6]!
		underlay_rect:   [f32(552), 189, 84, 26, 5, 5, 5, 5, 5, 5, 5, 5]!
		fill:            9
		anti_alias:      1
		force_msaa:      1
		has_float_color: 1
		float_color:     [f32(31) / 255, f32(35) / 255, f32(40) / 255, f32(10) / 255]!
	}
	bg := C.VoxGraphiteShape{ matrix: shadow.matrix, rect: [f32(551.5), 188.5, 85, 27, 5.5, 5.5,
		5.5, 5.5, 5.5, 5.5, 5.5, 5.5]!, fill: 1, anti_alias: 1, force_msaa: 1, red: 246, green: 248, blue: 250, alpha: 255 }
	border := C.VoxGraphiteShape{ ...bg, fill: 0, thickness: 1, red: 209, green: 217, blue: 224 }
	shapes := [shadow, bg, border]
	for grouped in [false, true] {
		mut pixels := []u8{len: 1024 * 768 * 4, init: 255}
		if grouped {
			assert draw_shapes(pixels.data, 1024, 768, 4096, 1, shapes.data, 3) == 1
		} else {
			for shape in shapes {
				assert draw(pixels.data, 1024, 768, 4096, 1, &shape) == 1
			}
		}
		mut n := 0
		for y in 188 .. 194 {
			for x in 551 .. 637 {
				i := (y * 1024 + x) * 4
				j := i
				mut differs := false
				for c in 0 .. 4 {
					ch := if c == 0 {
						2
					} else if c == 2 {
						0
					} else {
						c
					}
					if pixels[i + ch] != unsafe { ref.data[j + c] } { differs = true }
				}
				if differs { n++ }
			}
		}
		if grouped {
			assert n == 0, 'shared corner differences=${n}'
		} else {
			assert n > 0
		}
	}
}
