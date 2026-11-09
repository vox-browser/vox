module cpuraster

// Near the raster sigma limit, rescale() applies the source shader at
// identity scale. Sampling and color effects still resolve in that pass.
fn large_filter_uses_identity_rescale(ctm SkAffine, sigma f32) bool {
	if sigma < 0 || !is_finite_f32(sigma) { return false }
	sx, sy := blur_layer_sigma(math_abs32(sigma * ctm.sx)), blur_layer_sigma(math_abs32(sigma * ctm.sy))
	if !is_finite_f32(sx) || !is_finite_f32(sy)
		|| (sx <= image_blur_max_sigma && sy <= image_blur_max_sigma) { return false }
	rx := if sx > image_blur_max_sigma { image_blur_max_sigma / sx } else { f32(1) }
	ry := if sy > image_blur_max_sigma { image_blur_max_sigma / sy } else { f32(1) }
	return filter_downscale_steps(rx) == 0 && filter_downscale_steps(ry) == 0
}

// rescale() resolves a deferred minification before progressive downsampling
// when composing the two scales would omit source pixels. Near-identity
// downsampling and mappings that do not require this pass stay deferred.
fn large_filter_resolves_source_first(source SkAffine, ctm SkAffine, sigma f32) bool {
	if sigma < 0 || !is_finite_f32(sigma) || !affine_is_finite(source)
		|| filter_nearly_integer_translation(source) { return false }
	sx, sy := blur_layer_sigma(math_abs32(sigma * ctm.sx)), blur_layer_sigma(math_abs32(sigma * ctm.sy))
	if !is_finite_f32(sx) || !is_finite_f32(sy) { return false }
	rx := if sx > image_blur_max_sigma { image_blur_max_sigma / sx } else { f32(1) }
	ry := if sy > image_blur_max_sigma { image_blur_max_sigma / sy } else { f32(1) }
	xs, ys := filter_downscale_steps(rx), filter_downscale_steps(ry)
	nx, ny := math_abs32(source.sx * rx), math_abs32(source.sy * ry)
	if nx <= 0 || ny <= 0 || !is_finite_f32(nx) || !is_finite_f32(ny) { return false }
	return (xs > 0 && filter_downscale_steps(nx) > xs)
		|| (ys > 0 && filter_downscale_steps(ny) > ys)
}

// This initial resolve applies image sampling, paint alpha and incoming color
// filters together. The subsequent blur consumes that premultiplied surface;
// outgoing color filters remain deferred until restore.
fn draw_large_resolved_source_filter(mut pixels []u8, width int, height int, pitch int, alpha_type int, ctm SkAffine, dst Rect, view FilterImageView, mode BlendMode, clips []Path, step CanvasFilterStep) bool {
	mut target := new_canvas_target(mut pixels, width, height, pitch, alpha_type)
	rc := canvas_raster_clip(width, height, clips)
	bounds := step.source_draw_bounds or { dst }
	pad := f32(3) * step.sigma
	mut fast := Rect{bounds.left - pad, bounds.top - pad, bounds.right + pad, bounds.bottom + pad}
	drop := step.kind == .drop_shadow
	mut offset := SkAffine{}
	if drop {
		inverse := affine_invert(ctm) or { return false }
		offset = sk_concat(ctm, post_translate(inverse, step.offset_x, step.offset_y))
		if !affine_is_finite(offset) || math_abs32(offset.tx) > 1 << 24 || math_abs32(offset.ty) > 1 << 24 { return false }
		fast = Rect{fmin_std(bounds.left, fast.left + step.offset_x),
			fmin_std(bounds.top, fast.top + step.offset_y), fmax_std(bounds.right, fast.right + step.offset_x),
			fmax_std(bounds.bottom, fast.bottom + step.offset_y)}
	}
	if rc.is_empty || canvas_quick_reject(fast, affine_to_matrix(ctm), &rc) { return target.ready() }
	sx, sy := blur_layer_sigma(math_abs32(step.sigma * ctm.sx)), blur_layer_sigma(math_abs32(step.sigma * ctm.sy))
	rx, ry := skif_ceil(f32(3) * sx), skif_ceil(f32(3) * sy)
	desired := rc.bounds()
	requested := if drop {
		skif_outset(map_filter_bounds(desired, affine_invert(offset) or { return false }), 1, 1)
	} else { desired }
	output := requested.intersect(skif_outset(view.layer_bounds, rx, ry)) or { IRect{} }
	resolved := if output.is_empty() { FilterResult{} } else {
		resolve_filter_image_view(view, skif_outset(output, rx, ry)) or { return false }
	}
	blurred := scaled_blur_filter_view(resolved, requested, sx, sy, none, false) or { return false }
	if drop {
		max_dim := math_max_int(2 * math_max_int(desired.width(), desired.height()), 2048)
		merged := spatial_filter_merge(SpatialFilterValue{view: view},
			SpatialFilterValue{view: if blurred.bitmap.width > 0 { ?FilterImageView(blurred) } else { none }},
			offset, desired, step.color, max_dim) or { return false }
		target.ready()
		if !merged.image.has_image {
			draw_empty_filter_result(mut pixels, pitch, &rc, mode)
			return true
		}
		result := merged.image
		draw_color_filtered_bitmap(mut pixels, pitch, result.color_info.bitmap(result.image.bitmap()),
			result.origin_x, result.origin_y, &rc, mode, step.post_color, 1)
		return true
	}
	if blurred.bitmap.width == 0 {
		target.ready()
		draw_empty_filter_result(mut pixels, pitch, &rc, mode)
		return true
	}
	return draw_filter_image_view(mut pixels, pitch, &rc, mode,
		FilterImageView{...blurred, filter: new_color_filter(step.post_color)}, 0, 0, mut target)
}
