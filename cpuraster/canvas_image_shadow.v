module cpuraster

// An identity blur keeps MakeFromImage's transform and color effects deferred.
// Merge draws the offset SrcIn-tinted view below the original view.
fn draw_deferred_image_shadow(mut pixels []u8, width int, height int, pitch int, alpha_type int, ctm SkAffine, dst Rect, foreground FilterImageView, mode BlendMode, clips []Path, step CanvasFilterStep) bool {
	inverse := affine_invert(ctm) or { return false }
	offset := sk_concat(ctm, post_translate(inverse, step.offset_x, step.offset_y))
	if !affine_is_finite(offset) || math_abs32(offset.tx) > 1 << 24 || math_abs32(offset.ty) > 1 << 24 { return false }
	needs_resolve := !foreground.default_sampling && !foreground.smoothing
		&& !filter_nearly_integer_translation(offset)
	bitmap := foreground.bitmap
	if !foreground.layer_bounds.contains(map_filter_bounds(IRect{0, 0, bitmap.width, bitmap.height}, foreground.transform)) {
		return false
	}
	valid_blur := step.sigma >= 0 && is_finite_f32(step.sigma)
	shadow := FilterImageView{...foreground, transform: sk_concat(offset, foreground.transform),
		layer_bounds: map_filter_bounds(foreground.layer_bounds, offset),
		default_sampling: foreground.default_sampling || foreground.smoothing,
		filter: if valid_blur { foreground.filter } else { none }, tint: step.color}
	if !affine_is_finite(shadow.transform) { return false }
	if !needs_resolve && !shadow.layer_bounds.contains(
		map_filter_bounds(IRect{0, 0, bitmap.width, bitmap.height}, shadow.transform)) { return false }
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
	mut resolved_shadow := ?FilterResult(none)
	mut shadow_bounds := shadow.layer_bounds
	if needs_resolve {
		// applyTransform() resolves the tinted nearest source before its
		// linear offset. This preserves both sampling operations and their
		// intermediate quantization, while leaving the foreground deferred.
		input := FilterImageView{...shadow, transform: foreground.transform,
			layer_bounds: foreground.layer_bounds, default_sampling: foreground.default_sampling}
		tight := map_filter_bounds(rc.bounds(), affine_invert(offset) or { return false })
		resolved := resolve_filter_image_view(input, tight) or { return false }
		resolved_shadow = resolved
		shadow_bounds = if resolved.has_image { map_filter_bounds(resolved.layer_bounds, offset) } else { IRect{} }
	}
	has_shadow := irect_intersects(shadow_bounds, rc.bounds())
	has_foreground := foreground.filter == none || irect_intersects(foreground.layer_bounds, rc.bounds())
	foreground_bounds := if has_foreground { foreground.layer_bounds } else { IRect{} }
	if !has_shadow { shadow_bounds = IRect{} }
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
		if resolved := resolved_shadow {
			draw_resolved_filter_image(mut merged, mw * 4, &merge_clip, resolved, offset,
				padded.left, padded.top)
		} else {
			draw_filter_image_view(mut merged, mw * 4, &merge_clip, .src_over, shadow,
				padded.left, padded.top, mut merge_target)
		}
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
