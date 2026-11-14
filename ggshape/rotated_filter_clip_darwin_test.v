// vtest build: macos
module ggshape

import stbi

fn test_rotated_filter_keeps_the_author_clip_beyond_the_window() {
	background := $embed_file('@VMODROOT/Tests/Browser/Brave/diagnostic/large-orbit-underlay.png').to_bytes()
	back := stbi.load_from_memory(background.data, background.len, desired_channels: 4) or { panic('background') }
	defer { back.free() }
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/diagnostic/large-clipped-orbit.png').to_bytes()
	ref := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic('reference') }
	defer { ref.free() }
	assert back.width == 1024 && back.height == 768
	assert ref.width == 1024 && ref.height == 768
	// The picture starts at y=384, so its last visible tile starts at 638.
	// The author clip ends at ceil(840.59375)=841, beyond the window's 792.
	// Preserve that extent while preparing the input, then publish visible rows.
	for window_clip in [true, false] {
		matrix := [f32(.9135454), .40673664, 45.936813, -.40673664, .9135454, f32(541.7629) - 286,
			0, 0, 1]!
		hole := [f32(0), 0, 1000, 680, 500, 340, 500, 340, 500, 340, 500, 340]!
		unblurred := C.VoxGraphiteShape{
			matrix:          matrix
			rect:            [f32(0), -1, 1000, 680, 500, 340, 500, 340, 500, 340, 500, 340]!
			underlay_rect:   hole
			fill:            9
			anti_alias:      1
			force_msaa:      1
			has_float_color: 1
			float_color:     [f32(166) / 255, f32(198) / 255, f32(244) / 255, f32(13) / 255]!
		}
		blurred := C.VoxGraphiteShape{
			...unblurred
			rect:            [f32(0), -15, 1000, 680, 500, 340, 500, 340, 500, 340, 500, 340]!
			fill:            10
			thickness:       60
			float_color:     [f32(121) / 255, f32(168) / 255, f32(243) / 255, f32(9) / 255]!
			has_filter_clip: 1
			filter_clip:     [f32(33), -187, 991, if window_clip { f32(154) } else { f32(203) }]!
		}
		border := C.VoxGraphiteShape{
			matrix:        matrix
			rect:          [f32(.5), .5, 999, 679, 499.5, 339.5, 499.5, 339.5, 499.5, 339.5, 499.5,
				339.5]!
			fill:          6
			thickness:     1
			border_widths: [f32(1), 1, 1, 1]!
			anti_alias:    1
			force_msaa:    1
			red:           166
			green:         198
			blue:          244
			alpha:         21
		}
		shapes := [unblurred, blurred, border]
		mut pixels := []u8{len: 1024 * 256 * 4}
		for y in 0 .. 130 {
			for x in 0 .. 1024 {
				i := (y * 1024 + x) * 4
				j := ((y + 638) * 1024 + x) * 4
				pixels[i] = unsafe { back.data[j + 2] }
				pixels[i + 1] = unsafe { back.data[j + 1] }
				pixels[i + 2] = unsafe { back.data[j] }
				pixels[i + 3] = 255
			}
		}
		assert draw_shapes(pixels.data, 1024, 256, 4096, 1, shapes.data, 3) == 1
		mut different := 0
		for y in 1 .. 130 {
			for x in 33 .. 991 {
				i := (y * 1024 + x) * 4
				j := ((y + 638) * 1024 + x) * 4
				if pixels[i] != unsafe { ref.data[j + 2] }
					|| pixels[i + 1] != unsafe { ref.data[j + 1] }
					|| pixels[i + 2] != unsafe { ref.data[j] }
					|| pixels[i + 3] != unsafe { ref.data[j + 3] } {
					different++
				}
			}
		}
		eprintln('ROTATED_FILTER window_clip=${window_clip} different=${different}')
		if window_clip {
			assert different > 0
		} else {
			assert different == 0
		}
	}
}
