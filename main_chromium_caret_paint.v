module main

import gg
import layout

fn C.native_draw_caret_rect_srgb(f32, f32, f32, f32, gg.Color)

fn (app &BrowserApp) draw_chromium_caret(command &layout.PaintCommand, x f32, y f32,
	width f32, height f32, color gg.Color, non_axis_aligned bool) bool {
	$if macos {
		if command.is_caret && app.ctx.native_rendering && !non_axis_aligned
			&& command.radius == 0 && !command.outer_shadow && command.clip_outs.len == 0
			&& app.document != unsafe { nil }
			&& app.document.font_rendering_policy() == .chromium {
			C.native_draw_caret_rect_srgb(x, f32(app.ctx.height) - y - height, width, height, color)
			return true
		}
	}
	return false
}
