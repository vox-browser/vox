// vtest build: macos
module ggshape

import math
import stbi

fn test_joined_rotated_border_sides_keep_their_samples_until_resolve() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/rotated-border-join.png').to_bytes()
	expected := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic(err) }
	defer { expected.free() }
	for samples in [1, 4] {
		msaa := samples == 4
		w := if msaa { 128 } else { 1024 }
		ox, oy := if msaa { 904 } else { 0 }, if msaa { 0 } else { 508 }
		px, py := if msaa { 977 } else { 73 }, if msaa { 220 } else { 600 }
		c := f32(math.sqrt(.5))
		mut shapes := []C.VoxGraphiteShape{}
		for rect in [[f32(0), 4, 5, 1]!, [f32(4), 0, 1, 5]!] {
			shapes << C.VoxGraphiteShape{
				matrix:     [c, -c, f32(px - ox) + 2.5, c, c,
					f32(f64(py - oy) + .5 - 5 * math.sqrt(.5)), 0, 0, 1]!
				rect:       [rect[0], rect[1], rect[2], rect[3], f32(0), 0, 0, 0, 0, 0, 0, 0]!
				fill:       1
				anti_alias: 1
				force_msaa: int(msaa)
				red:        255
				green:      255
				blue:       255
				alpha:      255
			}
		}

		mut pixels := []u8{len: w * 256 * 4}
		if !msaa {
			for i in 0 .. w * 256 {
				pixels[i * 4], pixels[i * 4 + 1], pixels[i * 4 + 2], pixels[i * 4 + 3] = 98, 41, 5, 255
			}
		}
		result := draw_shapes(pixels.data, i32(w), 256, i32(w * 4), 1, shapes.data, 2)
		assert result == 1
		// The composited layer is transparent, while the root owns the navy
		// background. Resolve the layer before blending it over that background.
		if msaa {
			for i in 0 .. w * 256 {
				for ch, bg in [98, 41, 5] {
					pixels[i * 4 + ch] += u8((bg * (255 - int(pixels[i * 4 + 3])) + 127) / 255)
				}
				pixels[i * 4 + 3] = 255
			}
		}
		mut different := 0
		for y in py - oy - 4 .. py - oy + 8 {
			for x in px - ox - 6 .. px - ox + 10 {
				i := (y * w + x) * 4
				j := ((y + oy) * expected.width + x + ox) * 4
				if pixels[i..i + 4] != unsafe { [expected.data[j + 2], expected.data[j + 1],
					expected.data[j], expected.data[j + 3]] } {
					different++
				}
			}
		}
		assert different == 0, 'samples=${samples}, pixels=${different}'
	}
}
