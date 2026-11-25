// vtest build: macos
module ggshape

import stbi

fn test_analytic_rectangular_card_shadow_matches_brave() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/rectangular-card-shadow.png').to_bytes()
	expected := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic(err) }
	defer { expected.free() }
	for samples in [0, 1] {
		mut different := 0
		for row in 0 .. 4 {
			oy := row * 254
			mut pixels := []u8{len: 1024 * 256 * 4, init: 255}
			for y in 0 .. 256 {
				for x in 222 .. 802 {
					if y + oy >= 204 && y + oy < 668 {
						i := (y * 1024 + x) * 4
						pixels[i], pixels[i + 1], pixels[i + 2] = 138, 118, 89
					}
				}
			}
			shape := C.VoxGraphiteShape{
				matrix:          [f32(1), 0, 0, 0, 1, f32(-oy), 0, 0, 1]!
				rect:            [f32(276), 605, 518, 218, 0, 0, 0, 0, 0, 0, 0, 0]!
				underlay_rect:   [f32(264), 618, 558, 258, 0, 0, 0, 0, 0, 0, 0, 0]!
				fill:            10
				thickness:       30
				anti_alias:      1
				force_msaa:      samples
				has_float_color: 1
				float_color:     [f32(0), 0, 0, f32(77) / 255]!
			}
			assert draw(pixels.data, 1024, 256, 4096, 1, &shape) == 1
			for y in 0 .. 256 {
				for x in 264 .. 822 {
					if y + oy >= 618 && y + oy < 876 {
						i := (y * 1024 + x) * 4
						pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3] = 255, 255, 255, 255
					}
				}
			}
			for y in (if row == 0 { 0 } else { 1 }) .. (if row == 3 { 6 } else { 255 }) {
				for x in 0 .. 900 {
					i := (y * 1024 + x) * 4
					j := ((y + oy) * 1024 + x) * 4
					actual := pixels[i..i + 4]
					reference := unsafe {
						[expected.data[j + 2], expected.data[j + 1], expected.data[j],
							expected.data[j + 3]]
					}
					if actual != reference {
						different++
						for c in 0 .. 4 {
							assert int(actual[c]) - int(reference[c]) >= -1 && int(actual[c]) - int(reference[c]) <= 1
						}
					}
				}
			}
		}
		// One blue-channel tie remains at (774,615); do not widen this budget.
		assert different == 1
	}
}

fn test_rectangular_shadow_accepts_transfer_metadata_and_keeps_transform_fallbacks() {
	mut shape := C.VoxGraphiteShape{
		matrix:    [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
		rect:      [f32(10), 10, 40, 20, 0, 0, 0, 0, 0, 0, 0, 0]!
		fill:      10
		thickness: 12
	}
	assert rectangular_shadow_supported(&shape)
	// Filter input bounds describe rotated image-filter transfers. Like the
	// existing unrotated box-shadow path, rectangular mask geometry ignores them.
	shape.has_filter_clip = 1
	assert rectangular_shadow_supported(&shape)
	shape.has_filter_clip = 0
	shape.matrix[1] = f32(.25)
	assert !rectangular_shadow_supported(&shape)
	shape.matrix[1] = 0
	shape.rect[4] = 1
	assert !rectangular_shadow_supported(&shape)
}

fn test_rectangular_shadow_coverage_modulates_all_premultiplied_channels() {
	width, height := 63, 35
	for samples in [0, 1] {
		mut pixels := []u8{len: width * height * 4}
		shape := C.VoxGraphiteShape{
			matrix:          [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			rect:            [f32(10), 8, 40, 20, 0, 0, 0, 0, 0, 0, 0, 0]!
			fill:            10
			thickness:       4
			anti_alias:      1
			force_msaa:      samples
			has_float_color: 1
			float_color:     [f32(1), .5, .25, .8]!
		}
		assert draw(pixels.data, i32(width), i32(height), i32(width * 4), 0, &shape) == 1
		center := (16 * width + 30) * 4
		assert pixels[center..center + 4] == [u8(51), 102, 204, 204]
		// A pixel on the blurred edge has fractional coverage in every channel.
		edge := (16 * width + 9) * 4
		assert pixels[edge] > 0 && pixels[edge] < pixels[edge + 1]
		assert pixels[edge + 1] < pixels[edge + 2] && pixels[edge + 2] < 204
		assert pixels[edge + 2] == pixels[edge + 3]
		assert pixels[0..4] == [u8(0), 0, 0, 0]
	}
}
