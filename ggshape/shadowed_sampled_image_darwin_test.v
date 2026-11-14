// vtest build: macos
module ggshape

import stbi
import imageraster

fn test_shadowed_ellipse_keeps_image_and_shadow_samples_until_resolve() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/resources/shadowed-avatar.png').to_bytes()
	img := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic('source') }
	defer { img.free() }
	src := imageraster.decode_rgba(unsafe { img.data.vbytes(40 * 40 * 4) }, 40, 40, 20, 20) or { panic('decode') }
	b := $embed_file('@VMODROOT/Tests/Browser/Brave/diagnostic/shadowed-elliptical-avatar.png').to_bytes()
	ref := stbi.load_from_memory(b.data, b.len, desired_channels: 4) or { panic('ref') }
	defer { ref.free() }
	for alpha in [f32(38) / 255] {
		for joint in [false, true] {
			mut p := []u8{len: 1024 * 256 * 4, init: 255}
			rect := [f32(46), 73, 9, 20, 4.5, 10, 4.5, 10, 4.5, 10, 4.5, 10]!
			shape := C.VoxGraphiteShape{
				matrix:          [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
				rect:            [
					f32(45),
					72,
					11,
					22,
					5.5,
					11,
					5.5,
					11,
					5.5,
					11,
					5.5,
					11,
				]!
				underlay_rect:   rect
				fill:            9
				anti_alias:      1
				force_msaa:      1
				has_float_color: 1
				float_color:     [
					f32(31) / 255,
					f32(35) / 255,
					f32(40) / 255,
					alpha,
				]!
			}
			if joint {
				assert draw_sampled_rgba_with_shadow(p.data, 1024, 256, 4096, 1, src.pixels, 20, 20, 46, 73, 9, 20, 4, 40, 40, rect, false, &shape) == 1
			} else {
				assert draw(p.data, 1024, 256, 4096, 1, &shape) == 1
				assert draw_sampled_rgba_clipped(p.data, 1024, 256, 4096, 1, src.pixels, 20, 20, 46, 73, 9, 20, 4, 40, 40, rect, false) == 1
			}
			mut n := 0
			for y in 65 .. 102 {
				for x in 40 .. 63 {
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
						if p[i + ch] != unsafe { ref.data[j + c] } { d = true }
					}
					if d { n++ }
				}
			}
			if joint {
				assert n == 0, 'shared shadow/image differences=${n}'
			} else {
				assert n > 0
			}
		}
	}
}

fn test_shadowed_sampled_image_rejects_filtered_underlays_without_mutating_pixels() {
	source := []u8{len: 4 * 4 * 4, init: 255}
	mut pixels := []u8{len: 16 * 16 * 4, init: 123}
	shadow := C.VoxGraphiteShape{ fill: 9, thickness: 1 }
	assert draw_sampled_rgba_with_shadow(pixels.data, 16, 16, 64, 1, source, 4, 4, 4, 4, 4, 4, 1, 4, 4, [12]f32{}, false, &shadow) == 0
	assert pixels.all(it == 123)
}
