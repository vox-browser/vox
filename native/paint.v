module main

import gg

fn C.vox_browser_frame_prepared()
fn C.vox_browser_frame_completed()
fn C.vox_browser_has_paint_context() int

// Cocoa already supplies a drawing context for the native view. Sokol's
// immediate-mode projection/pass is only needed by the portable renderer.
fn begin_browser_frame(ctx &gg.Context) {
	$if macos {
		if ctx.native_rendering {
			C.vox_browser_frame_prepared()
			return
		}
	}
	ctx.begin()
}

fn end_browser_frame(ctx &gg.Context) {
	$if macos {
		if ctx.native_rendering {
			C.vox_browser_frame_completed()
			return
		}
	}
	ctx.end()
}

fn draw_browser_polygon(ctx &gg.Context, points []f32, color gg.Color) {
	if points.len < 6 { return }
	$if macos {
		if ctx.native_rendering {
			unsafe { C.native_draw_polygon_srgb(&points[0], points.len / 2, f32(ctx.height), color) }
			return
		}
	}
	ctx.draw_convex_poly(points, color)
}

fn draw_browser_line(ctx &gg.Context, x f32, y f32, x2 f32, y2 f32, config gg.PenConfig) {
	$if macos {
		if ctx.native_rendering {
			line_style := match config.line_type {
				.dotted { 1 }
				.dashed { 2 }
				else { 0 }
			}

			C.native_draw_line_srgb(x, y, x2, y2, config.thickness, line_style, f32(ctx.width),
				f32(ctx.height), config.color)
			return
		}
	}
	ctx.draw_line_with_config(x, y, x2, y2, config)
}
