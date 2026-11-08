module cpuraster

// Retained text shadows save an unbounded layer, paint opaque glyphs, blur
// the result, then apply a single SrcIn tint when restoring through the clip.
pub fn rasterize_text_shadow(width int, height int, run CanvasGlyphRun, transform [6]f32, color u32, blur f32, clips []Path) ?[]u8 {
	if width <= 0 || height <= 0 || width > max_untiled_dimension || height > max_untiled_dimension { return none }
	mut pixels := []u8{len: width*height*4}
	step := CanvasFilterStep{kind: .blur, sigma: blur / f32(2)}
	retained := CanvasGlyphRun{...run, baseline_snap: true}
	if !draw_filter_layer_tinted(mut pixels, width, height, width*4, 2, transform, clips,
		none, step, .src_over, fn [retained, color] (mut layer []u8, w int, h int, t [6]f32, inner_clips []Path) bool {
		return fill_canvas_glyphs_surface(mut layer, w, h, w*4, 2, retained, t, color | 0xff000000,
			none, 1, .src_over, inner_clips, none, true)
	}, color) { return none }
	mut straight := []u8{len: pixels.len}
	if !read_pixels(pixels, width, height, width*4, 2, mut straight, width, height, width*4, 0, 0) { return none }
	return straight
}
