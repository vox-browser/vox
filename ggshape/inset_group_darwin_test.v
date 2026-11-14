// vtest build: macos
module ggshape

import stbi

fn test_inset_decorations_keep_corner_samples_through_one_resolve() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/diagnostic/inset-decoration-samples.png').to_bytes()
	ref := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic('reference') }
	defer { ref.free() }
	assert ref.width == 1280 && ref.height == 800
	for grouped in [false, true] {
		mut pixels := []u8{len: 1280 * 256 * 4}
		for i in 0 .. 1280 * 256 {
			pixels[i * 4] = 51
			pixels[i * 4 + 1] = 34
			pixels[i * 4 + 2] = 23
			pixels[i * 4 + 3] = 255
		}
		for box in 0 .. 2 {
			x := if box == 0 { f32(48) } else { f32(400) }
			// Border decoration geometry is snapped independently of the CSS position.
			y := f32(43)
			h := if box == 0 { f32(130) } else { f32(600) }
			rb := if box == 0 { f32(12.5) } else { f32(0) }
			ri := if box == 0 { f32(12) } else { f32(0) }
			bg := C.VoxGraphiteShape{
				matrix:     [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
				rect:       [x + .5, y + .5, 299, h - 1, 12.5, 12.5, 12.5, 12.5, rb, rb, rb, rb]!
				fill:       1
				anti_alias: 1
				force_msaa: 1
				red:        16
				green:      23
				blue:       34
				alpha:      255
			}
			shadow := C.VoxGraphiteShape{
				matrix:                bg.matrix
				rect:                  [x + 1, y + 1, 298, h - 1, 0, 0, 0, 0, 0, 0, 0, 0]!
				underlay_rect:         [x + 1, y + 2, 298, h - 2, 12, 12, 12, 12, ri, ri, ri, ri]!
				contour_reference:     [x + 1, y + 1, 298, h - 2, 12, 12, 12, 12, ri, ri, ri, ri]!
				has_contour_reference: 1
				fill:                  14
				anti_alias:            1
				force_msaa:            1
				has_float_color:       1
				float_color:           [f32(1), 1, 1, f32(8) / 255]!
			}
			border := C.VoxGraphiteShape{ ...bg, fill: 0, thickness: 1, red: 52, green: 65, blue: 81 }
			shapes := [bg, shadow, border]
			if grouped {
				assert draw_shapes(pixels.data, 1280, 256, 5120, 1, shapes.data, 3) == 1
			} else {
				for shape in shapes {
					assert draw(pixels.data, 1280, 256, 5120, 1, &shape) == 1
				}
			}
		}
		mut different := 0
		for y in 40 .. 180 {
			for x in 40 .. 708 {
				mut d := false
				for c in 0 .. 4 {
					ch := if c == 0 {
						2
					} else if c == 2 {
						0
					} else {
						c
					}
					if pixels[(y * 1280 + x) * 4 + ch] != unsafe { ref.data[(y * 1280 + x) * 4 + c] } {
						d = true
					}
				}
				if d { different++ }
			}
		}
		eprintln('INSET grouped=${grouped} different=${different}')
		if grouped {
			assert different == 0
		} else {
			assert different > 0
		}
	}
}
