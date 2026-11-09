module cpuraster

struct DeferredImageShadow {
	view FilterImageView
	offset SkAffine
	resolved ?FilterResult
	bounds IRect
}

// An identity blur leaves the tint on the deferred source. A fractional
// linear offset of a nearest source instead resolves that tinted input first.
fn prepare_deferred_image_shadow(foreground FilterImageView, offset SkAffine, desired IRect, color u32, valid_blur bool) ?DeferredImageShadow {
	needs_resolve := !foreground.default_sampling && !foreground.smoothing
		&& !filter_nearly_integer_translation(offset)
	bitmap := foreground.bitmap
	if !foreground.layer_bounds.contains(map_filter_bounds(IRect{0, 0, bitmap.width, bitmap.height}, foreground.transform)) {
		return none
	}
	shadow := FilterImageView{...foreground, transform: sk_concat(offset, foreground.transform),
		layer_bounds: map_filter_bounds(foreground.layer_bounds, offset),
		default_sampling: foreground.default_sampling || foreground.smoothing,
		filter: if valid_blur { foreground.filter } else { none }, tint: color}
	if !affine_is_finite(shadow.transform) { return none }
	if !needs_resolve && !shadow.layer_bounds.contains(
		map_filter_bounds(IRect{0, 0, bitmap.width, bitmap.height}, shadow.transform)) { return none }
	mut resolved := ?FilterResult(none)
	mut bounds := shadow.layer_bounds
	if needs_resolve {
		input := FilterImageView{...shadow, transform: foreground.transform,
			layer_bounds: foreground.layer_bounds, default_sampling: foreground.default_sampling}
		tight := map_filter_bounds(desired, affine_invert(offset) or { return none })
		image := resolve_filter_image_view(input, tight) or { return none }
		resolved = image
		bounds = if image.has_image { map_filter_bounds(image.layer_bounds, offset) } else { IRect{} }
	}
	return DeferredImageShadow{shadow, offset, resolved, bounds}
}

fn draw_prepared_image_shadow(mut pixels []u8, pitch int, rc &RasterClip, shadow DeferredImageShadow, origin_x int, origin_y int, mut target CanvasTarget) bool {
	if result := shadow.resolved {
		draw_resolved_filter_image(mut pixels, pitch, rc, result, shadow.offset, origin_x, origin_y)
		return true
	}
	return draw_filter_image_view(mut pixels, pitch, rc, .src_over, shadow.view, origin_x, origin_y, mut target)
}

// An identity blur keeps MakeFromImage's transform and color effects deferred.
// Merge draws the offset SrcIn-tinted view below the original view.
fn draw_deferred_image_shadow(mut pixels []u8, width int, height int, pitch int, alpha_type int, ctm SkAffine, dst Rect, foreground FilterImageView, mode BlendMode, clips []Path, step CanvasFilterStep) bool {
	inverse := affine_invert(ctm) or { return false }
	offset := sk_concat(ctm, post_translate(inverse, step.offset_x, step.offset_y))
	if !affine_is_finite(offset) || math_abs32(offset.tx) > 1 << 24 || math_abs32(offset.ty) > 1 << 24 { return false }
	valid_blur := step.sigma >= 0 && is_finite_f32(step.sigma)
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
	shadow := prepare_deferred_image_shadow(foreground, offset, rc.bounds(), step.color, valid_blur) or { return false }
	mut shadow_bounds := shadow.bounds
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
		if !draw_prepared_image_shadow(mut merged, mw * 4, &merge_clip, shadow,
			padded.left, padded.top, mut merge_target) { return false }
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
