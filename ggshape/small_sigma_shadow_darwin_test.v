// vtest build: macos
module ggshape

import stbi

// The opaque foreground is a separate draw. Compare its exterior shadow band
// against fresh Brave captures, including the one-pass sigma=.5 rounding case.
fn test_small_sigma_rounded_shadow_matches_brave_outside_the_opaque_box() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/small-blur-shadows.png').to_bytes()
	expected := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic('reference') }
	defer { expected.free() }
	for variant in 0 .. 3 {
		y := if variant == 0 {
			f32(16)
		} else if variant == 1 {
			f32(80)
		} else {
			f32(144)
		}
		radii := if variant == 2 {
			[f32(50), 16, 50, 16, 50, 16, 50, 16]!
		} else {
			[f32(6), 6, 6, 6, 6, 6, 6, 6]!
		}
		for samples in [i32(0), 1] {
			shape := C.VoxGraphiteShape{
				matrix:          [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
				rect:            [f32(148), y, 100, 32, radii[0], radii[1], radii[2], radii[3],
					radii[4], radii[5], radii[6], radii[7]]!
				underlay_rect:   [f32(148), y, 100, 32, radii[0], radii[1], radii[2], radii[3],
					radii[4], radii[5], radii[6], radii[7]]!
				fill:            10
				thickness:       if variant == 1 { f32(1.5) } else { f32(1) }
				anti_alias:      1
				force_msaa:      samples
				has_float_color: 1
				float_color:     [f32(0), 0, 0, f32(8) / 15]!
			}
			mut pixels := []u8{len: 280 * 192 * 4, init: 255}
			assert draw(pixels.data, 280, 192, 280 * 4, 1, &shape) == 1
			mut differing := 0
			for row in int(y) - 8 .. int(y) + 40 {
				for x in 132 .. 264 {
					if x >= 148 && x < 248 && row >= int(y) && row < int(y) + 32 { continue }
					i := (row * 280 + x) * 4
					for c in 0 .. 4 {
						channel := if c == 0 {
							2
						} else if c == 2 {
							0
						} else {
							c
						}
						if pixels[i + channel] != unsafe { expected.data[i + c] } { differing++ }
					}
				}
			}
			assert differing == 0, 'variant=${variant} samples=${samples} channels=${differing}'
		}
	}
}

fn test_small_sigma_shadow_rejects_smaller_kernels_without_changing_pixels() {
	for blur in [f32(0), .5, .98] {
		shape := C.VoxGraphiteShape{
			matrix:    [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			rect:      [f32(4), 4, 40, 24, 6, 6, 6, 6, 6, 6, 6, 6]!
			fill:      10
			thickness: blur
		}
		mut pixels := []u8{len: 48 * 32 * 4, init: 0xa5}
		assert draw(pixels.data, 48, 32, 48 * 4, 1, &shape) == 0
		assert pixels.all(it == 0xa5)
	}
}
