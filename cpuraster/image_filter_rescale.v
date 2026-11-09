module cpuraster

import math

// FilterResult::rescale() for decal sources. Each pass keeps
// its logical bounds in floats, while the backing image has an integer
// extent and a transparent pixel around it. The upscale remains deferred.
fn filter_downscale_steps(scale f32) int {
	mut steps := 0
	count := int(ceil_f32(f32(1) / scale))
	for (1 << steps) < count { steps++ }
	if steps > 0 {
		final := scale * f32(1 << (steps - 1))
		limit := if steps == 1 { f32(1) - image_filter_round_epsilon } else { f32(.9) }
		if final >= limit { steps-- }
	}
	return steps
}

fn filter_scale_about_center(src Rect, sx f32, sy f32) Rect {
	hl, hr := f32(.5) * src.left, f32(.5) * src.right
	ht, hb := f32(.5) * src.top, f32(.5) * src.bottom
	cx := if sx == 1 { f32(0) } else { hl + hr }
	cy := if sy == 1 { f32(0) } else { ht + hb }
	return Rect{(src.left - cx) * sx, (src.top - cy) * sy, (src.right - cx) * sx, (src.bottom - cy) * sy}
}

// The integer-bounds inverse retains double precision rather than first
// rounding the inverse matrix to floats (LayerSpace<SkMatrix>::inverseMapRect).
fn inverse_scale_filter_bounds(bounds IRect, transform SkAffine) IRect {
	l := (f64(bounds.left) - transform.tx) / transform.sx
	r := (f64(bounds.right) - transform.tx) / transform.sx
	t := (f64(bounds.top) - transform.ty) / transform.sy
	b := (f64(bounds.bottom) - transform.ty) / transform.sy
	e := f64(image_filter_round_epsilon)
	return IRect{double_saturate_to_int(math.floor(math.min(l, r) + e)), double_saturate_to_int(math.floor(math.min(t, b) + e)), double_saturate_to_int(math.ceil(math.max(l, r) - e)), double_saturate_to_int(math.ceil(math.max(t, b) - e))}
}

fn rescale_filter_shader(image FilterResult, transform SkAffine, destination IRect, origin_x int, origin_y int) CanvasShader {
	w, h := image.image.width(), image.image.height()
	placed := affine_translate(f32(image.origin_x), f32(image.origin_y))
	net := sk_concat(transform, placed)
	output := Rect{f32(destination.left), f32(destination.top), f32(destination.right), f32(destination.bottom)}
	covered := filter_quad_contains_rect(net, Rect{0, 0, f32(w), f32(h)}, output).all(it)
	x_aligned, y_aligned := filter_nearly_integer_axes(net)
	ex, ey := if x_aligned { f32(0) } else { image_filter_round_epsilon }, if y_aligned {
		f32(0)
	} else {
		image_filter_round_epsilon
	}
	pad := if image.transparent_boundary || image.initialized_boundary { f32(1) } else { f32(0) }
	safe := Rect{f32(.5) + ex - pad, f32(.5) + ey - pad, f32(w) - f32(.5) - ex + pad, f32(h) - f32(.5) - ey + pad}
	centers := Rect{output.left + f32(.5), output.top + f32(.5), output.right - f32(.5), output.bottom - f32(.5)}
	edges := filter_quad_contains_rect(net, safe, centers)
	subset := image.image.subset
	backing := image.image.backing
	strict := !(edges[0] || subset.top == 0) || !(edges[1] || subset.right == backing.width)
		|| !(edges[2] || subset.bottom == backing.height) || !(edges[3] || subset.left == 0)
	device := sk_concat(affine_translate(-f32(origin_x), -f32(origin_y)), transform)
	if strict && image.transparent_boundary {
		pixels := SpecialImage{backing, skif_outset(subset, 1, 1)}.bitmap()
		total := sk_concat(device, pre_translate(placed, -1, -1))
		return new_image_shader(image.color_info.bitmap(pixels), .clamp, .clamp, true, total)
	}
	pixels := if strict { image.image.bitmap() } else { backing }
	local := if strict {
		placed
	} else {
		pre_translate(placed, -f32(subset.left), -f32(subset.top))
	}
	tile := if covered { TileMode.clamp } else { TileMode.decal }
	return new_image_shader(image.color_info.bitmap(pixels), tile, tile, true, sk_concat(device, local))
}

fn downscale_filter_input(source FilterResult, desired IRect, scale_x f32, scale_y f32, filter ?ColorFilter, deferred ?DeferredRescaleImage) ?(FilterResult, SkAffine) {
	layer_bounds := if input := deferred { input.view.layer_bounds } else { source.layer_bounds }
	visible := layer_bounds.intersect(desired) or { return FilterResult{}, SkAffine{} }
	mut xs, mut ys := filter_downscale_steps(scale_x), filter_downscale_steps(scale_y)
	if deferred == none && xs == 0 && ys == 0 && filter == none && !source.color_info.display_p3 && source.color_info.alpha == 1 {
		return source.subset(visible), SkAffine{}
	}
	src := Rect{f32(visible.left), f32(visible.top), f32(visible.right), f32(visible.bottom)}
	mut logical := src
	mut image := source
	// Color filtering follows sampling in the first pass, without an
	// intermediate 8-bit quantization of the source.
	mut first := deferred
	mut pending := if input := deferred { input.view.filter } else { filter }
	final_x, final_y := if xs > 0 { scale_x } else { f32(1) }, if ys > 0 { scale_y } else { f32(1) }
	for {
		mut sx, mut sy := f32(1), f32(1)
		if xs > 0 {
			sx = if xs > 1 {
				f32(.5)
			} else {
				f32(visible.width()) * final_x / (logical.right - logical.left)
			}
			xs--
		}
		if ys > 0 {
			sy = if ys > 1 {
				f32(.5)
			} else {
				f32(visible.height()) * final_y / (logical.bottom - logical.top)
			}
			ys--
		}
		next := filter_scale_about_center(logical, sx, sy)
		bounds := skif_round_out(next)
		if bounds.is_empty() { return FilterResult{}, SkAffine{} }
		padded := skif_outset(bounds, 1, 1)
		w, h := padded.width(), padded.height()
		if w > max_untiled_dimension || h > max_untiled_dimension { return none }
		mut pixels := []u8{len: w * h * 4}
		transform := rect_to_rect(logical, next) or { return none }
		shader := if input := first { rescale_source_image_shader(input, transform, bounds, padded.left, padded.top) }
			else { rescale_filter_shader(image, transform, bounds, padded.left, padded.top) }
		alpha := if input := first { input.view.alpha } else { image.color_info.alpha }
		// Default sampling can use the native N32 shader context. Mipmapped
		// sources and the paint's deferred alpha filter stay in the pipeline.
		legacy := canvas_rgba_uses_legacy() && if input := first {
			input.view.default_sampling && input.view.alpha == 1
		} else { true }
		rc := canvas_raster_clip(w, h, [])
		if mut blitter := canvas_draw_blitter_for_surface(mut pixels, w * 4, 0xff000000, shader, alpha, .src,
			Rect{1, 1, f32(w - 1), f32(h - 1)}, pending, legacy) {
			fill_irect(IRect{1, 1, w - 1, h - 1}, &rc, mut blitter)
		}
		pending = none
		first = none
		image = new_filter_result(SpecialImage{BlurImage{pixels, w, h}, IRect{0, 0, w, h}}, padded.left, padded.top).inset_for_save_layer()
		logical = next
		if xs == 0 && ys == 0 { break }
	}
	restore := rect_to_rect(logical, src) or { return none }
	return image, restore
}

// Builder::blur() downsamples sigmas beyond the raster engine's limit,
// blurs in low-resolution pixels, and retains the transform until restore.
fn scaled_blur_filter_view(source FilterResult, desired IRect, sigma_x f32, sigma_y f32, filter ?ColorFilter, native_context bool) ?FilterImageView {
	return scaled_blur_input_view(source, desired, sigma_x, sigma_y, filter, native_context, none)
}

fn scaled_blur_input_view(source FilterResult, desired IRect, sigma_x f32, sigma_y f32, filter ?ColorFilter, native_context bool, deferred ?DeferredRescaleImage) ?FilterImageView {
	if deferred == none && !source.has_image { return FilterImageView{} }
	rx, ry := skif_ceil(f32(3) * sigma_x), skif_ceil(f32(3) * sigma_y)
	layer_bounds := if input := deferred { input.view.layer_bounds } else { source.layer_bounds }
	output := desired.intersect(skif_outset(layer_bounds, rx, ry)) or { return FilterImageView{} }
	sample := skif_outset(output, rx, ry)
	scale_x := if sigma_x > image_blur_max_sigma { image_blur_max_sigma / sigma_x } else { f32(1) }
	scale_y := if sigma_y > image_blur_max_sigma { image_blur_max_sigma / sigma_y } else { f32(1) }
	low, restore := downscale_filter_input(source, sample, scale_x, scale_y, filter, deferred)?
	if !low.has_image { return FilterImageView{} }
	transform := sk_concat(restore, affine_translate(f32(low.origin_x), f32(low.origin_y)))
	sx := fmin_std(sigma_x * (f32(1) / transform.sx), image_blur_max_sigma)
	sy := fmin_std(sigma_y * (f32(1) / transform.sy), image_blur_max_sigma)
	wanted := inverse_scale_filter_bounds(output, transform)
	maximum := skif_outset(IRect{0, 0, low.image.width(), low.image.height()}, skif_ceil(f32(3) * sx), skif_ceil(f32(3) * sy))
	relative := wanted.intersect(maximum) or { return FilterImageView{} }
	padded := skif_outset(relative, 1, 1)
	if padded.width() > max_untiled_dimension || padded.height() > max_untiled_dimension {
		return none
	}
	image := low.image.bitmap()
	blurred, subset := blur_8888(sx, sy, image, IRect{0, 0, image.width, image.height}, padded)
	result := new_filter_result(SpecialImage{blurred, subset}, padded.left, padded.top).inset_by_pixel()
	if !result.has_image { return FilterImageView{} }
	total := sk_concat(transform, affine_translate(f32(result.origin_x), f32(result.origin_y)))
	bounds := desired.intersect(map_filter_bounds(IRect{0, 0, result.image.width(), result.image.height()}, total)) or { return FilterImageView{} }
	bitmap := CanvasBitmap{ ...low.color_info.bitmap(result.image.bitmap()), native_n32: native_context || canvas_rgba_uses_legacy() }
	return FilterImageView{
		bitmap:           bitmap
		native_context:   native_context
		special_image:    result.image
		transform:        total
		layer_bounds:     bounds
		layer_crop:       true
		default_sampling: true
		smoothing:        true
	}
}

// A saved canvas layer has already rasterized its content in layer space.
// Rescale and blur before restoring, keeping post-filter color math deferred.
fn draw_large_blur_layer(mut pixels []u8, pitch int, rc &RasterClip, mode BlendMode, layer BlurImage, origin_x int, origin_y int, sigma_x f32, sigma_y f32, step CanvasFilterStep, mut target CanvasTarget) bool {
	filter := new_color_filter(step.pre_color)
	image := layer
	saved := new_filter_result(SpecialImage{image, IRect{0, 0, image.width, image.height}}, 0, 0).inset_for_save_layer()
	mut source := FilterResult{ ...saved, color_info: step.source_color_info }
	clip := rc.bounds()
	mut desired := IRect{clip.left - origin_x, clip.top - origin_y, clip.right - origin_x, clip.bottom - origin_y}
	mut base_x, mut base_y := origin_x, origin_y
	if step.source_image {
		// MakeFromImage evaluates its filter graph in the original layer
		// coordinates. Saved canvas layers evaluate relative to their buffer.
		source = FilterResult{ ...source.translated(origin_x, origin_y), transparent_boundary: step.source_padding }
		desired = clip
		base_x, base_y = 0, 0
	}
	local := scaled_blur_filter_view(source, desired, sigma_x, sigma_y, filter, !step.source_image) or { return false }
	if local.bitmap.width == 0 {
		target.ready()
		draw_empty_filter_result(mut pixels, pitch, rc, mode)
		return true
	}
	view := FilterImageView{ ...local, filter: new_color_filter(step.post_color) }
	return draw_filter_image_view(mut pixels, pitch, rc, mode, view, -base_x, -base_y, mut target)
}
