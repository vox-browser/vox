module main

import os
import gg.canvas
import sokol.gfx

$if windows {
	import gg
	import sokol.sapp
}

$if !sokol_d3d11 ? {
	import ggshape
}

fn main() {
	$if windows {
		if os.args.len != 2 {
			eprintln('Usage: windows-graphics-smoke OUTPUT.png')
			exit(2)
		}
		run_windows_graphics_smoke()
	} $else {
		if os.args.len != 2 || os.args[1] != '--offscreen' {
			eprintln('Usage: windows-graphics-smoke --offscreen on macOS or Linux')
			exit(2)
		}
		check_canvas_solid_fills() or { panic(err) }
		check_svg_stroke_pixels() or { panic(err) }
	}
}

$if windows {
	struct WindowsGraphicsSmoke {
	mut:
		ctx &gg.Context = unsafe { nil }
	}

	fn run_windows_graphics_smoke() {
		mut state := &WindowsGraphicsSmoke{}
		state.ctx = gg.new_context(
			width:        320
			height:       240
			window_title: 'Vox Windows graphics smoke'
			bg_color:     gg.white
			init_fn:      fn (mut state WindowsGraphicsSmoke) {
				$if sokol_d3d11 ? {
					configure_windows_browser_renderer(state.ctx)
					check_d3d11_pixel_regions(17, 11, .bgra8, [u8(255), 0, 0, 255]!)
					check_d3d11_pixel_regions(17, 11, .rgba8, [u8(0), 0, 255, 255]!)
					check_d3d11_pixel_regions(1025, 1024, .rgba8, [u8(0), 0, 255, 255]!)
					println('D3D11 BGRA8 and RGBA8 pitched texture transfers passed')
				} $else {
					check_svg_stroke_pixels() or { panic(err) }
				}
				check_canvas_solid_fills() or { panic(err) }
			}
			frame_fn:     fn (mut state WindowsGraphicsSmoke) {
				begin_browser_frame(state.ctx)
				state.ctx.draw_rect_filled(20, 30, 80, 50, gg.red)
				state.ctx.draw_rect_filled(180, 130, 60, 70, gg.blue)
				state.ctx.draw_text(20, 100, 'Windows', color: gg.black, size: 20)
				end_browser_frame(state.ctx)
				if state.ctx.frame == 2 {
					sapp.screenshot_png(os.args[1]) or { panic(err) }
					println('Windows GG projection, color and text smoke: captured')
					sapp.quit()
				}
			}
			user_data:    state
		)
		$if !sokol_d3d11 ? {
			state.ctx.window.gl.major_version = 4
			state.ctx.window.gl.minor_version = 3
			eprintln('Windows GG graphics smoke: starting the OpenGL window')
		}
		state.ctx.run()
	}
}

$if windows && sokol_d3d11 ? {
	// The smoke executable uses -prod, which drops V assertions.
	fn require_d3d11_check(ok bool, message string) {
		if !ok {
			panic(message)
		}
	}

	fn check_d3d11_pixel_regions(width int, height int, format gfx.PixelFormat, clear [4]u8) {
		target := gfx.make_image(&gfx.ImageDesc{
			width: width
			height: height
			render_target: true
			pixel_format: format
		})
		require_d3d11_check(gfx.query_image_state(target) == .valid, 'D3D11 render target allocation failed')
		defer { gfx.destroy_image(target) }
		mut desc := gfx.AttachmentsDesc{}
		desc.colors[0].image = target
		attachments := gfx.make_attachments(&desc)
		require_d3d11_check(gfx.query_attachments_state(attachments) == .valid, 'D3D11 attachment allocation failed')
		defer { gfx.destroy_attachments(attachments) }

		left, top, patch_width, patch_height := 3, 2, 5, 4
		source_pitch := patch_width * 4 + 5
		mut source := []u8{len: source_pitch * patch_height, init: 0xa5}
		for y in 0 .. patch_height {
			for x in 0 .. patch_width {
				offset := y * source_pitch + x * 4
				source[offset] = u8(17 + x)
				source[offset + 1] = u8(23 + y)
				source[offset + 2] = 61
				source[offset + 3] = 127
			}
		}
		pitch := width * 4 + 7
		mut pixels := []u8{len: pitch * height, init: 0xcc}
		mut pass := gfx.Pass{ attachments: attachments }
		pass.action.colors[0].load_action = .clear
		pass.action.colors[0].clear_value = gfx.Color{0, 0, 1, 1}
		gfx.begin_pass(&pass)
		require_d3d11_check(!gfx.read_image(target, 0, 0, width, height, pixels.data, pitch),
			'D3D11 accepted readback during a render pass')
		require_d3d11_check(!gfx.write_image(target, left, top, patch_width, patch_height, source.data, source_pitch),
			'D3D11 accepted an upload during a render pass')
		gfx.end_pass()
		require_d3d11_check(!gfx.write_image(target, -1, top, patch_width, patch_height, source.data, source_pitch),
			'D3D11 accepted an out-of-bounds rectangle')
		require_d3d11_check(!gfx.read_image(target, 0, 0, width, height, pixels.data, width * 4 - 1),
			'D3D11 accepted a short readback stride')
		require_d3d11_check(gfx.write_image(target, left, top, patch_width, patch_height, source.data, source_pitch),
			'D3D11 subrectangle upload failed')
		require_d3d11_check(gfx.read_image(target, 0, 0, width, height, pixels.data, pitch),
			'D3D11 render target readback failed')
		for y in 0 .. height {
			for x in 0 .. width {
				offset := y * pitch + x * 4
				if x >= left && x < left + patch_width && y >= top && y < top + patch_height {
					start := (y - top) * source_pitch + (x - left) * 4
					require_d3d11_check(pixels[offset..offset + 4] == source[start..start + 4],
						'D3D11 altered pixels within the uploaded rectangle')
				} else {
					require_d3d11_check(pixels[offset..offset + 4] == clear[..],
						'D3D11 altered surrounding pixels')
				}
			}
			require_d3d11_check(pixels[y * pitch + width * 4..(y + 1) * pitch].all(it == 0xcc),
				'D3D11 readback altered destination row padding')
		}
		mut cropped := []u8{len: 8}
		require_d3d11_check(gfx.read_image(target, left + 1, top + 2, 2, 1, cropped.data, cropped.len),
			'D3D11 subrectangle readback failed')
		start := 2 * source_pitch + 4
		require_d3d11_check(cropped == source[start..start + cropped.len],
			'D3D11 subrectangle readback returned the wrong pixels')
	}
}

fn expect_canvas_pixel(pixels []u8, pitch int, x int, y int, color [4]u8) ! {
	offset := y * pitch + x * 4
	actual := pixels[offset..offset + 4]
	if actual != color[..] {
		return error('Canvas pixel (${x}, ${y}) is ${actual}, expected ${color}')
	}
}

fn check_canvas_solid_fills() ! {
	width, height := 32, 24
	pitch := width * 4 + 7
	pixels := []u8{len: pitch * height, init: 0xcc}
	mut ctx := canvas.new_gpu_context()!
	defer { ctx.free() }
	mut target := ctx.new_surface(width: width, height: height)!
	defer { target.free() }
	target.clear(canvas.Color4f{})
	target.draw_rect(canvas.Rect.ltrb(2, 1, 13, 7), canvas.Paint.rgba8(255, 0, 0, 255))!
	target.draw_rect(canvas.Rect.ltrb(3, 2, 8, 5), canvas.Paint.rgba8(0, 0, 255, 128))!
	target.read_pixels(pixels.data, pitch)!
	expect_canvas_pixel(pixels, pitch, 10, 3, [u8(0), 0, 255, 255]!)!
	expect_canvas_pixel(pixels, pitch, 5, 3, [u8(128), 0, 127, 255]!)!
	expect_canvas_pixel(pixels, pitch, 10, 20, [u8(0), 0, 0, 0]!)!

	// A convex curved triangle uses the shaded wedge pass. It upgrades the
	// surface to a multisample pass and must preserve the first resolve.
	mut path := canvas.PathBuilder{}
	path.move_to(18, 2)
	path.quad_to(28, 0, 30, 5)
	path.line_to(18, 9)
	path.close()
	curve := path.detach()
	if !curve.is_convex() {
		return error('Canvas curved fixture must use the shaded wedge pass')
	}
	target.draw_path(curve, canvas.Paint.rgba8(0, 255, 255, 255))!
	target.read_pixels(pixels.data, pitch)!
	expect_canvas_pixel(pixels, pitch, 5, 3, [u8(128), 0, 127, 255]!)!
	expect_canvas_pixel(pixels, pitch, 20, 4, [u8(255), 255, 0, 255]!)!

	// The nested, nonrectangular contours force stencil and cover. The same
	// orientation leaves a hole under even-odd and fills it under winding.
	path.move_to(4, 11)
	path.line_to(30, 11)
	path.line_to(27, 22)
	path.line_to(2, 22)
	path.close()
	path.move_to(10, 14)
	path.line_to(21, 14)
	path.line_to(16, 20)
	path.close()
	contours := path.detach()
	green := [u8(0), 255, 0, 255]!
	transparent := [u8(0), 0, 0, 0]!
	for fill_type in [canvas.PathFillType.even_odd, .winding, .inverse_even_odd] {
		target.clear(canvas.Color4f{})
		target.draw_path(canvas.Path{
			verbs:     contours.verbs
			points:    contours.points
			weights:   contours.weights
			fill_type: fill_type
		}, canvas.Paint.rgba8(0, 255, 0, 255))!
		target.read_pixels(pixels.data, pitch)!
		expect_canvas_pixel(pixels, pitch, 6, 14, if fill_type == .inverse_even_odd {
			transparent
		} else {
			green
		})!
		expect_canvas_pixel(pixels, pitch, 16, 16, if fill_type == .even_odd {
			transparent
		} else {
			green
		})!
		expect_canvas_pixel(pixels, pitch, 26, 5, if fill_type == .inverse_even_odd {
			green
		} else {
			transparent
		})!
	}
	// Seed the resolve with an inverse fill so a partial blit would leave
	// stale color outside the next pass's scissor, even after a clear.
	expect_canvas_pixel(pixels, pitch, 26, 5, green)!
	target.clear(canvas.Color4f{})
	target.clip_path(canvas.Path{
		verbs:     contours.verbs
		points:    contours.points
		weights:   contours.weights
		fill_type: .even_odd
	}, .intersect, true)!
	target.draw_rect(canvas.Rect.ltrb(0, 0, width, height), canvas.Paint.rgba8(0, 255, 0, 255))!
	target.read_pixels(pixels.data, pitch)!
	expect_canvas_pixel(pixels, pitch, 6, 14, green)!
	expect_canvas_pixel(pixels, pitch, 16, 16, transparent)!
	expect_canvas_pixel(pixels, pitch, 26, 5, transparent)!

	$if windows && sokol_d3d11 ? {
		mut recovery := ctx.new_surface(width: width, height: height)!
		defer { recovery.free() }
		recovery.clear(canvas.Color4f.from_rgba8(0, 255, 0, 255))
		recovery.flush()!
		recovery.draw_oval(canvas.Rect.ltrb(2, 2, 20, 20), canvas.Paint.rgba8(255, 0, 0, 255))!
		mut rejected := false
		recovery.flush() or { rejected = err.msg().contains('D3D11 supports solid') }
		if !rejected {
			return error('D3D11 Canvas must reject an unsupported pass before drawing')
		}
		recovery.draw_rect(canvas.Rect.ltrb(1, 1, 6, 6), canvas.Paint.rgba8(255, 0, 0, 255))!
		recovery.read_pixels(pixels.data, pitch)!
		expect_canvas_pixel(pixels, pitch, 4, 4, [u8(0), 0, 255, 255]!)!
		expect_canvas_pixel(pixels, pitch, 10, 10, green)!
	}
	for y in 0 .. height {
		if !pixels[y * pitch + width * 4..(y + 1) * pitch].all(it == 0xcc) {
			return error('Canvas readback altered destination row padding')
		}
	}
	println('GG Canvas solid rectangle, blend, curve, fill rules and MSAA reload passed on ${gfx.query_backend()}')
}

$if !sokol_d3d11 ? {
	fn check_svg_stroke_pixels() ! {
		mut gpu := canvas.new_gpu_context()!
		defer { gpu.free() }
		mut target := gpu.new_surface(width: 32, height: 16)!
		defer { target.free() }
		segments := [f32(0), 4, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			1, 28, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0]
		stops := [f32(1), 0, 0, 1, 0, 0, 0, 1, 1, 1]
		path := C.VoxGraphitePath{
			matrix:          [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			segments:        segments.data
			segment_count:   2
			stroke:          1
			stroke_width:    4
			gradient:        1
			gradient_points: [f32(12), 8, 20, 8, 0, 0]!
			gradient_matrix: [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			opacity:         1
			stop_count:      2
			stops:           stops.data
		}
		target.clear(canvas.Color4f{})
		ggshape.record_svg_path(mut target, &path, none)!
		row_bytes := 32 * 4
		pitch := row_bytes + 8
		pixels := []u8{len: pitch * 16, init: 42}
		target.read_pixels(pixels.data, pitch)!
		left := 8 * pitch + 8 * 4
		middle := 8 * pitch + 15 * 4
		right := 8 * pitch + 24 * 4
		outside := 5 * pitch + 8 * 4
		if pixels[left..left + 4] != [u8(0), 0, 255, 255]
			|| pixels[right..right + 4] != [u8(255), 0, 0, 255]
			|| pixels[outside..outside + 4] != [u8(0), 0, 0, 0] {
			return error('Unexpected Canvas SVG gradient stroke pixels')
		}
		// Pixel center x=15.5 lies 7/16 of the way from red to blue.
		if pixels[middle] !in [u8(111), 112] || pixels[middle + 1] != 0
			|| pixels[middle + 2] !in [u8(143), 144] || pixels[middle + 3] != 255 {
			return error('Unexpected Canvas SVG gradient midpoint ${pixels[middle..middle + 4]}')
		}
		for row in 0 .. 16 {
			for byte in pixels[row * pitch + row_bytes..(row + 1) * pitch] {
				if byte != 42 { return error('Canvas SVG readback changed padding on row ${row}') }
			}
		}
		println('GG Canvas SVG gradient stroke and readback stride passed on ${gfx.query_backend()}')
	}
}
