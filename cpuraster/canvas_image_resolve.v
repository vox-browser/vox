module cpuraster

// FilterResult::resolve() with pending image effects: draw into a premultiplied
// sRGB surface, leaving one transparent pixel around the requested subset.
// None denotes an unsupported surface size; an empty result is supported.
fn resolve_filter_image_view(view FilterImageView, requested IRect) ?FilterResult {
	bounds := requested.intersect(view.layer_bounds) or { return FilterResult{} }
	padded := skif_outset(bounds, 1, 1)
	w, h := padded.width(), padded.height()
	if w > max_untiled_dimension || h > max_untiled_dimension { return none }
	mut pixels := []u8{len: w * h * 4}
	rc := canvas_raster_clip(w, h, [rect_path(Rect{1, 1, f32(w - 1), f32(h - 1)})])
	mut target := new_canvas_target(mut pixels, w, h, w * 4, 2)
	if !draw_filter_image_view(mut pixels, w * 4, &rc, .src_over, view,
		padded.left, padded.top, mut target) { return none }
	return new_filter_result(SpecialImage{BlurImage{pixels, w, h}, IRect{0, 0, w, h}},
		padded.left, padded.top).inset_for_save_layer()
}

// A resolved image has no pending tint or color conversion. Its transparent
// boundary allows a non-AA outset draw with linear sampling, as drawSpecial()
// does for FilterResult::draw(). Direct image filters retain the destination
// RGBA color type, including on Linux where native N32 would be BGRA.
fn draw_resolved_filter_image(mut pixels []u8, pitch int, rc &RasterClip, result FilterResult, offset SkAffine, origin_x int, origin_y int) {
	image := SpecialImage{result.image.backing, skif_outset(result.image.subset, 1, 1)}.bitmap()
	bitmap := CanvasBitmap{...FilterImageInfo{}.bitmap(image), native_n32: canvas_rgba_uses_legacy()}
	transformed := sk_concat(offset, affine_translate(f32(result.origin_x), f32(result.origin_y)))
	net := sk_concat(affine_translate(-f32(origin_x), -f32(origin_y)), transformed)
	total := pre_translate(net, -1, -1)
	linear := !filter_nearly_integer_translation(transformed)
	dev := map_rect_corners(total, Rect{0, 0, f32(image.width), f32(image.height)})
	mut clip := round_rect(dev)
	bounds := map_filter_bounds(result.layer_bounds, offset)
	// A transparent boundary normally draws its full pixel outset, rather
	// than clipping to the rounded logical layer bounds. Legacy bilerp's
	// four-bit weights can remain nonzero just beyond those bounds.
	if !bounds.contains(map_filter_bounds(IRect{0, 0, result.image.width(), result.image.height()}, transformed)) {
		clip = clip.intersect(IRect{bounds.left - origin_x, bounds.top - origin_y,
			bounds.right - origin_x, bounds.bottom - origin_y}) or { return }
	}
	shader := new_image_shader(bitmap, .clamp, .clamp, linear, total)
	if mut blitter := canvas_paint_blitter_for_surface(mut pixels, pitch, 0xff000000,
		shader, 1, .src_over, dev, canvas_rgba_uses_legacy()) {
		fill_irect(clip, rc, mut blitter)
	}
}
