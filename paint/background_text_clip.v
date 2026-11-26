module main

import cpuraster
import layout
import painting
import platform

fn (mut app BrowserApp) begin_portable_background_text_clip(command &layout.PaintCommand,
	page_x f32, page_y f32) {
	transform := portable_device_transform(command.transform, page_x, page_y, f64(app.ctx.scale))
	local := painting.Rect{command.x, command.y, command.width, command.height}
	bounds := portable_pixel_bounds(transform.map_rect(local).intersection(app.portable_device_viewport(page_y)))
	mut pixels := []u8{len: bounds.width * bounds.height * 4}
	if pixels.len > 0 {
		matrix := [f32(transform.a), f32(transform.b), f32(transform.c), f32(transform.d),
			f32(transform.e - f64(bounds.x)), f32(transform.f - f64(bounds.y))]!
		mut cache := document_glyph_cache()
		for clip_run in command.text_clip_runs {
			glyphs := clip_run.glyph_run or { continue }
			font := glyphs.font()
			if font.is_invisible { continue }
			font_path := if glyphs.face() == .emoji {
				platform.emoji_font_path() or { continue }
			} else {
				font.font_path() or { continue }
			}
			run := cpuraster.CanvasGlyphRun{
				font_path:     font_path
				face_index:    font.face_index()
				font_size:     font.point_size
				glyphs:        glyphs.glyph_indices()
				positions:     glyphs.glyph_positions().map(f32(it))
				translation:   [f32(clip_run.glyph_translation_x), f32(clip_run.glyph_translation_y)]!
				baseline_snap: true
				retained:      true
				smoothing:     0
			}
			cpuraster.fill_canvas_glyphs_cached(mut cache, mut pixels, bounds.width, bounds.height,
				bounds.width * 4, 2, run, matrix, 0xff000000, none, 1, .src_over, [], none)
		}
	}
	app.portable_background_text_clip = PortableBackgroundTextClip{bounds, pixels}
}
