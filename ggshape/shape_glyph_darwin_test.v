// vtest build: macos
module ggshape

import math
import stbi
import gg.canvas

fn test_shape_glyph_group_rejects_incomplete_coverage_before_drawing() {
	shape := C.VoxGraphiteShape{
		matrix: [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
		rect:   [f32(0), 0, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0]!
		fill:   1
		red:    255
		alpha:  255
	}
	original := []u8{len: 16, init: u8(index * 13)}
	for invalid in [
		GlyphCoverage{ pixels: [u8(255), 255, 255], color: [f32(1), 1, 1, 1]! },
		GlyphCoverage{ pixels: [u8(255), 255, 255, 255], color: [f32(1), 1, 1, f32(math.nan())]! },
		GlyphCoverage{ pixels: [u8(255), 255, 255, 255], color: [f32(1), 1, 1, 2]! },
	] {
		mut pixels := original.clone()
		assert draw_shapes_with_glyphs(pixels.data, 2, 2, 8, 1, &shape, 1, [invalid]) == 0
		assert pixels == original
	}
}

fn test_glyph_coverage_keeps_rotated_shadow_samples_until_the_final_resolve() {
	back := stbi.load('${@VMODROOT}/Tests/Browser/Brave/diagnostic/large-orbit-underlay.png',
		desired_channels: 4
	) or { panic(err) }
	defer { back.free() }
	ref := stbi.load('${@VMODROOT}/Tests/Browser/Brave/diagnostic/orbit-text-band.png',
		desired_channels: 4
	) or { panic(err) }
	defer { ref.free() }
	coverage := stbi.load('${@VMODROOT}/Tests/Browser/Brave/diagnostic/orbit-text-coverage.png',
		desired_channels: 1
	) or { panic(err) }
	defer { coverage.free() }
	mask := unsafe { coverage.data.vbytes(446 * 25) }
	mut ctx := context() or { panic(err) }
	for joint in [false, true] {
		mut different := 0
		for row in 0 .. 2 {
			origin := 384 + row * 254
			m := [f32(.9135454), .40673664, 45.936813, -.40673664, .9135454,
				f32(541.7629) + f32(-32 - row * 254), 0, 0, 1]!
			a := C.VoxGraphiteShape{ matrix: m, rect: [f32(0), -1, 1000, 680, 500, 340, 500, 340,
				500, 340, 500, 340]!, underlay_rect: [f32(0), 0, 1000, 680, 500, 340, 500, 340,
				500, 340, 500, 340]!, fill: 9, anti_alias: 1, force_msaa: 1, has_float_color: 1, float_color: [
				f32(166) / 255,
				f32(198) / 255,
				f32(244) / 255,
				f32(13) / 255,
			]! }
			b := C.VoxGraphiteShape{ ...a, rect: [f32(0), -15, 1000, 680, 500, 340, 500, 340, 500,
				340, 500, 340]!, fill: 10, thickness: 60, float_color: [f32(121) / 255, f32(168) / 255,
				f32(243) / 255, f32(9) / 255]!, has_filter_clip: 1, filter_clip: [
				f32(33),
				451 - f32(origin),
				991,
				841 - f32(origin),
			]! }
			c := C.VoxGraphiteShape{ matrix: m, rect: [f32(.5), .5, 999, 679, 499.5, 339.5, 499.5,
				339.5, 499.5, 339.5, 499.5, 339.5]!, fill: 6, thickness: 1, border_widths: [
				f32(1),
				1,
				1,
				1,
			]!, anti_alias: 1, force_msaa: 1, red: 166, green: 198, blue: 244, alpha: 21 }
			shapes := [a, b, c]
			mut p := []u8{len: 1024 * 256 * 4}
			mut alpha := []u8{len: 1024 * 256}
			for y in 0 .. 256 {
				if origin + y >= 768 { continue }
				for x in 0 .. 1024 {
					i := (y * 1024 + x) * 4
					j := ((origin + y) * 1024 + x) * 4
					p[i] = unsafe { back.data[j + 2] }
					p[i + 1] = unsafe { back.data[j + 1] }
					p[i + 2] = unsafe { back.data[j] }
					p[i + 3] = 255
					if x >= 481 && x < 927 && origin + y >= 624 && origin + y < 649 {
						alpha[y * 1024 + x] = mask[(origin + y - 624) * 446 + x - 481]
					}
				}
			}
			if !joint {
				assert draw_shapes(p.data, 1024, 256, 4096, 1, shapes.data, 3) == 1
			}
			if joint {
				assert draw_shapes_with_glyphs(p.data, 1024, 256, 4096, 1, shapes.data, 3, [GlyphCoverage{ pixels: alpha, color: [
					f32(157) / 255,
					f32(170) / 255,
					f32(190) / 255,
					1,
				]! }]) == 1
			} else {
				mut surface := ctx.new_surface(width: 1024, height: 256, sample_count: 4) or { panic(err) }
				surface.write_pixels(p.data, 4096) or { panic(err) }
				surface.draw_msaa_trigger()

				surface.set_matrix(canvas.Matrix.identity())
				surface.draw_alpha_mask(alpha, 1024, 256, canvas.Paint{ color: canvas.Color4f{f32(157) / 255, f32(170) / 255, f32(190) / 255, 1} }) or { panic(err) }
				surface.read_pixels(p.data, 4096) or { panic(err) }
				surface.free()
			}
			for dy in 624 .. 649 {
				y := dy - origin
				if y < 0 || y >= 256 || (row == 0 && y >= 255) || (row == 1 && y == 0) { continue }
				for x in 600 .. 927 {
					i := (y * 1024 + x) * 4
					j := ((dy - 624) * 327 + x - 600) * 4
					if p[i] != unsafe { ref.data[j + 2] } || p[i + 1] != unsafe { ref.data[j + 1] } || p[i + 2] != unsafe { ref.data[j] } {
						different++
					}
				}
			}
		}
		assert different == if joint { 0 } else { 50 }
	}
}
