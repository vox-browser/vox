module main

// Text masks use the same retained glyph coverage as document text. Black is
// significant: Chromium's gamma/contrast adjustment depends on paint color,
// even though clipping consumes only the resulting alpha.
@[export: 'vox_draw_background_glyph_mask']
fn draw_background_glyph_mask(glyphs &u16, positions &f64, count i32, size f32,
	weight i32, baseline_x f32, baseline_y f32, a f32, b f32, c f32, d f32, e f32,
	f f32, page_x f32, page_y f32, scroll_y f32, width f32, height f32,
	font_path string, face_index i32, smoothing i32) i32 {
	if count <= 0 || count > 1000000 || glyphs == unsafe { nil }
		|| positions == unsafe { nil } || smoothing & 16 == 0 {
		return 0
	}
	unsafe {
		return i32(draw_document_glyph_raster([]u16{len: int(count), init: glyphs[index]},
			[]f64{len: int(count) * 2, init: positions[index]}, font_path, int(face_index), size,
			int(weight), baseline_x, baseline_y, [a, b, c, d, e, f]!, page_x, page_y,
			scroll_y, width, height, u32(0xff000000), int(smoothing), [f32(0), 0, 0, 1]!))
	}
}
