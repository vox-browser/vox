module main

import os

$if windows {
	import gg
	import sokol.sapp
}

$if !sokol_d3d11 ? {
	import gg.canvas
	import ggshape
	import sokol.gfx
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
				} $else {
					check_svg_stroke_pixels() or { panic(err) }
				}
			}
			frame_fn:     fn (mut state WindowsGraphicsSmoke) {
				begin_browser_frame(state.ctx)
				state.ctx.draw_rect_filled(20, 30, 80, 50, gg.red)
				state.ctx.draw_rect_filled(180, 130, 60, 70, gg.blue)
				state.ctx.draw_text(20, 100, 'Windows', color: gg.black, size: 20)
				end_browser_frame(state.ctx)
				if state.ctx.frame >= 2 {
					sapp.screenshot_png(os.args[1]) or { panic(err) }
					println('Windows GG projection, color and text smoke: captured')
					exit(0)
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
