module cpuraster

// Linux has no CoreText scaler: glyph runs decline (LibWeb Skia draws them
// with FreeType).
struct GlyphFace {
	font         voidptr
	color_glyphs bool
	variable     bool
}

fn open_glyph_face(path string) ?GlyphFace {
	return none
}

fn (f GlyphFace) release() {}

fn (f GlyphFace) exact_copy(text_size f64) ?voidptr {
	return none
}

fn release_glyph_font(font voidptr) {}

fn (f GlyphFace) font_bounds(size f32) ?Rect {
	return none
}

struct GlyphMetrics {
	x      f64
	y      f64
	width  f64
	height f64
}

fn glyph_metrics(font voidptr, id u16, transform [6]f64) ?GlyphMetrics {
	return none
}

fn draw_glyph(font voidptr, id u16, transform [6]f64, invertible bool, x f64, y f64, context_width int, context_height int, width int, height int, color bool, foreground u32) ?[]u32 {
	return none
}

fn glyph_path(font voidptr, id u16, transform [6]f64, sx f64, sy f64) ?[]f64 {
	return none
}
