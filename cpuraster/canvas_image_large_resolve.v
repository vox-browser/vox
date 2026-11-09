module cpuraster

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
fn draw_large_resolved_source_blur(mut pixels []u8, width int, height int, pitch int, alpha_type int, ctm SkAffine, dst Rect, view FilterImageView, mode BlendMode, clips []Path, step CanvasFilterStep) bool {
	mut target := new_canvas_target(mut pixels, width, height, pitch, alpha_type)
	rc := canvas_raster_clip(width, height, clips)
	bounds := step.source_draw_bounds or { dst }
	pad := f32(3) * step.sigma
	fast := Rect{bounds.left - pad, bounds.top - pad, bounds.right + pad, bounds.bottom + pad}
	if rc.is_empty || canvas_quick_reject(fast, affine_to_matrix(ctm), &rc) { return target.ready() }
	sx, sy := blur_layer_sigma(math_abs32(step.sigma * ctm.sx)), blur_layer_sigma(math_abs32(step.sigma * ctm.sy))
	rx, ry := skif_ceil(f32(3) * sx), skif_ceil(f32(3) * sy)
	desired := rc.bounds()
	output := desired.intersect(skif_outset(view.layer_bounds, rx, ry)) or {
		target.ready()
		draw_empty_filter_result(mut pixels, pitch, &rc, mode)
		return true
	}
	resolved := resolve_filter_image_view(view, skif_outset(output, rx, ry)) or { return false }
	blurred := scaled_blur_filter_view(resolved, desired, sx, sy, none, false) or { return false }
	if blurred.bitmap.width == 0 {
		target.ready()
		draw_empty_filter_result(mut pixels, pitch, &rc, mode)
		return true
	}
	return draw_filter_image_view(mut pixels, pitch, &rc, mode,
		FilterImageView{...blurred, filter: new_color_filter(step.post_color)}, 0, 0, mut target)
}
