// vtest build: macos
module ggshape

import stbi

fn test_rounded_background_and_border_share_their_corner_samples() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/rounded-background-border-root.png').to_bytes()
	ref := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic('reference') }
	defer { ref.free() }
	assert ref.width == 1280 && ref.height == 800
	for grouped in [false, true] {
		mut pixels := []u8{len: 1280 * 256 * 4}
		for i in 0 .. 1280 * 256 {
			pixels[i * 4] = 15
			pixels[i * 4 + 1] = 11
			pixels[i * 4 + 2] = 9
			pixels[i * 4 + 3] = 255
		}
		for box in [[372, 253, 0], [637, 217, 1], [854, 54, 2]] {
			radii := if box[2] == 0 {
				[f32(9.5), 9.5, 9.5, 9.5, 9.5, 9.5, 9.5, 9.5]!
			} else if box[2] == 1 {
				[f32(9.5), 9.5, 0, 0, 0, 0, 9.5, 9.5]!
			} else {
				[f32(0), 0, 9.5, 9.5, 9.5, 9.5, 0, 0]!
			}
			bg := C.VoxGraphiteShape{
				matrix:     [f32(1), 0, 0, 0, 1, -254, 0, 0, 1]!
				rect:       [f32(box[0]) + .5, 266.5, f32(box[1] - 1), 51, radii[0], radii[1],
					radii[2], radii[3], radii[4], radii[5], radii[6], radii[7]]!
				fill:       1
				anti_alias: 1
				force_msaa: 1
				red:        if box[2] == 0 { u8(18) } else { u8(70) }
				green:      if box[2] == 0 { u8(22) } else { u8(127) }
				blue:       if box[2] == 0 { u8(28) } else { u8(194) }
				alpha:      255
			}
			border := C.VoxGraphiteShape{
				...bg
				fill:      0
				thickness: 1
				red:       if box[2] == 0 {
					u8(59)
				} else if box[2] == 1 {
					u8(82)
				} else {
					u8(99)
				}
				green:     if box[2] == 0 {
					u8(70)
				} else if box[2] == 1 {
					u8(143)
				} else {
					u8(151)
				}
				blue:      if box[2] == 0 {
					u8(86)
				} else if box[2] == 1 {
					u8(212)
				} else {
					u8(211)
				}
			}
			shapes := [bg, border]
			if grouped {
				assert draw_shapes(pixels.data, 1280, 256, 5120, 1, shapes.data, 2) == 1
			} else {
				for shape in shapes {
					assert draw(pixels.data, 1280, 256, 5120, 1, &shape) == 1
				}
			}
		}
		mut different := 0
		for y in 266 .. 318 {
			if y >= 276 && y < 308 { continue }
			for x in 372 .. 908 {
				mut differs := false
				for c in 0 .. 4 {
					ch := if c == 0 {
						2
					} else if c == 2 {
						0
					} else {
						c
					}
					if pixels[((y - 254) * 1280 + x) * 4 + ch] != unsafe { ref.data[(y * 1280 + x) * 4 + c] } {
						differs = true
					}
				}
				if differs { different++ }
			}
		}
		eprintln('BACKGROUND grouped=${grouped} differences=${different}')
		if grouped {
			assert different == 0
		} else {
			assert different > 0
		}
	}
}
