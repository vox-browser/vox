module cpuraster

// An identity blur keeps MakeFromImage's transform and color effects deferred.
// Merge draws the offset SrcIn-tinted view below the original view.
fn draw_deferred_image_shadow(mut pixels []u8, width int, height int, pitch int, alpha_type int, ctm SkAffine, dst Rect, foreground FilterImageView, mode BlendMode, clips []Path, step CanvasFilterStep) bool {
	inverse := affine_invert(ctm) or { return false }
	offset := sk_concat(ctm, post_translate(inverse, step.offset_x, step.offset_y))
	if !affine_is_finite(offset) || math_abs32(offset.tx) > 1 << 24 || math_abs32(offset.ty) > 1 << 24 { return false }
	if !foreground.default_sampling && !foreground.smoothing && !filter_nearly_integer_translation(offset) {
		// Nearest source sampling followed by a fractional linear offset
		// requires a resolve surface before the transform can be applied.
		return false
	}
	bitmap := foreground.bitmap
	if !foreground.layer_bounds.contains(map_filter_bounds(IRect{0, 0, bitmap.width, bitmap.height}, foreground.transform)) {
		return false
	}
	valid_blur := step.sigma >= 0 && is_finite_f32(step.sigma)
	shadow := FilterImageView{...foreground, transform: sk_concat(offset, foreground.transform),
		layer_bounds: map_filter_bounds(foreground.layer_bounds, offset),
		default_sampling: foreground.default_sampling || foreground.smoothing,
		filter: if valid_blur { foreground.filter } else { none }, tint: step.color}
	if !affine_is_finite(shadow.transform)
		|| !shadow.layer_bounds.contains(map_filter_bounds(IRect{0, 0, bitmap.width, bitmap.height}, shadow.transform)) { return false }
	mut target := new_canvas_target(mut pixels, width, height, pitch, alpha_type)
	rc := canvas_raster_clip(width, height, clips)
	bounds := step.source_draw_bounds or { dst }
	pad := if valid_blur { f32(3) * step.sigma } else { f32(0) }
	shifted := Rect{bounds.left - pad + step.offset_x, bounds.top - pad + step.offset_y,
		bounds.right + pad + step.offset_x, bounds.bottom + pad + step.offset_y}
	fast := Rect{fmin_std(bounds.left, shifted.left), fmin_std(bounds.top, shifted.top),
		fmax_std(bounds.right, shifted.right), fmax_std(bounds.bottom, shifted.bottom)}
	if canvas_quick_reject(fast, affine_to_matrix(ctm), &rc) || rc.is_empty { return target.ready() }
	// applyTransform() drops an offset image outside the desired output.
	// A foreground color-filter node also drops a nonintersecting source.
	// Empty inputs must not widen the merge bounds or change its origin.
	has_shadow := irect_intersects(shadow.layer_bounds, rc.bounds())
	has_foreground := foreground.filter == none || irect_intersects(foreground.layer_bounds, rc.bounds())
	foreground_bounds := if has_foreground { foreground.layer_bounds } else { IRect{} }
	shadow_bounds := if has_shadow { shadow.layer_bounds } else { IRect{} }
	merged_bounds := union_filter_bounds(foreground_bounds, shadow_bounds).intersect(rc.bounds()) or {
		target.ready()
		draw_empty_filter_result(mut pixels, pitch, &rc, mode)
		return true
	}
	padded := skif_outset(merged_bounds, 1, 1)
	mw, mh := padded.width(), padded.height()
	if mw > max_untiled_dimension || mh > max_untiled_dimension { return false }
	mut merged := []u8{len: mw * mh * 4}
	merge_clip := canvas_raster_clip(mw, mh, [rect_path(Rect{1, 1, f32(mw - 1), f32(mh - 1)})])
	mut merge_target := new_canvas_target(mut merged, mw, mh, mw * 4, 2)
	// Both views are finite and axial and use source-over, so neither draw
	// can enter an unsupported rotated clearing or path rasterization case.
	if has_shadow {
		draw_filter_image_view(mut merged, mw * 4, &merge_clip, .src_over, shadow,
			padded.left, padded.top, mut merge_target)
	}
	if has_foreground {
		draw_filter_image_view(mut merged, mw * 4, &merge_clip, .src_over, foreground,
			padded.left, padded.top, mut merge_target)
	}
	target.ready()
	draw_color_filtered_sprite(mut pixels, pitch, BlurImage{merged, mw, mh}, padded.left,
		padded.top, &rc, mode, step.post_color)
	return true
}
