module cpuraster

// A sequence of raster blurs shares one source layer. Each filter requests
// its input bounds from the preceding filter and retains its own quantized
// intermediate image, as the native image-filter graph does.
fn draw_blur_filter_chain(mut pixels []u8, width int, height int, pitch int, alpha_type int, transform [6]f32, clips []Path, content_bounds ?Rect, quick_bounds ?Rect, stages []BlurFilterStage, post_color []MatrixColorFilter, source_info FilterImageInfo, source_image bool, source_padding bool, mode BlendMode, content LayerContent) bool {
	ctm := canvas_affine(transform)
	if ctm.kx != 0 || ctm.ky != 0 { return false }
	sigmas := stages.map(it.sigma)
	mut sx := []f32{cap: sigmas.len}
	mut sy := []f32{cap: sigmas.len}
	for sigma in sigmas {
		x := blur_layer_sigma(math_abs32(sigma * ctm.sx))
		y := blur_layer_sigma(math_abs32(sigma * ctm.sy))
		if x > image_blur_max_sigma || y > image_blur_max_sigma { return false }
		sx << x
		sy << y
	}
	mut target := new_canvas_target(mut pixels, width, height, pitch, alpha_type)
	rc := canvas_raster_clip(width, height, clips)
	if bounds := quick_bounds {
		mut fast := bounds
		for sigma in sigmas {
			pad := f32(3) * sigma
			fast = Rect{fast.left - pad, fast.top - pad, fast.right + pad, fast.bottom + pad}
		}
		if canvas_quick_reject(fast, affine_to_matrix(ctm), &rc) { return target.ready() }
	}
	if rc.is_empty || ctm.sx == 0 || ctm.sy == 0 || !affine_is_finite(ctm) { return target.ready() }
	output := rc.bounds()
	mut requested := []IRect{len: sigmas.len}
	mut needed := output
	for i := sigmas.len - 1; i >= 0; i-- {
		requested[i] = needed
		needed = skif_outset(needed, skif_ceil(f32(3) * sx[i]), skif_ceil(f32(3) * sy[i]))
	}
	mut layer := needed
	if bounds := content_bounds {
		device := skif_round_out(map_rect_affine(bounds, affine_to_matrix(ctm)))
		layer = layer.intersect(device) or {
			target.ready()
			draw_empty_filter_result(mut pixels, pitch, &rc, mode)
			return true
		}
	}
	max_dim := math_max_int(2 * math_max_int(output.width(), output.height()), 2048)
	// Check intermediate dimensions before drawing the source, too.
	mut predicted := layer
	for i in 0 .. sigmas.len {
		if sx[i] != 0 || sy[i] != 0 {
			predicted = skif_outset(predicted, skif_ceil(f32(3) * sx[i]), skif_ceil(f32(3) * sy[i]))
			predicted = predicted.intersect(requested[i]) or { IRect{} }
		}
		if predicted.width() > max_dim || predicted.height() > max_dim { return false }
	}
	padded := skif_outset(layer, 1, 1)
	lw, lh := padded.width(), padded.height()
	if lw > max_dim || lh > max_dim || lw > max_untiled_dimension || lh > max_untiled_dimension { return false }
	mut layer_pixels := []u8{len: lw * lh * 4}
	left, top := f32(padded.left), f32(padded.top)
	zero_x, zero_y := -left * f32(0), -top * f32(0)
	shift_x, shift_y := -left * f32(1), -top * f32(1)
	layer_transform := [zero_x + ctm.sx, zero_y + ctm.ky, zero_x + ctm.kx,
		zero_y + ctm.sy, shift_x + ctm.tx, shift_y + ctm.ty]!
	inner_clip := rect_path(Rect{1, 1, f32(lw - 1), f32(lh - 1)})
	if !content(mut layer_pixels, lw, lh, layer_transform, [inner_clip]) { return false }
	saved := new_filter_result(SpecialImage{BlurImage{layer_pixels, lw, lh}, IRect{0, 0, lw, lh}}, 0, 0).inset_for_save_layer()
	mut result := FilterResult{...saved, color_info: source_info,
		transparent_boundary: !source_image || source_padding}
	base_x := if source_image { 0 } else { padded.left }
	base_y := if source_image { 0 } else { padded.top }
	if source_image { result = result.translated(padded.left, padded.top) }
	mut pending := []MatrixColorFilter{}
	for i, desired_global in requested {
		pending << stages[i].pre_color
		if result.has_image && (sx[i] != 0 || sy[i] != 0) {
			incoming_color := new_color_filter(pending)
			if incoming_color != none || result.color_info.display_p3 || result.color_info.alpha != 1 {
				// A real blur resolves its child's deferred color filter into
				// N32 pixels. Identity passes preserve it without quantization.
				result = FilterResult{...result, image: SpecialImage{
					filter_layer_source_image(result.image.backing, result.color_info, incoming_color), result.image.subset},
					color_info: FilterImageInfo{}}
			}
			pending.clear()
		}
		desired := if source_image { desired_global } else {
			IRect{desired_global.left - padded.left, desired_global.top - padded.top,
				desired_global.right - padded.left, desired_global.bottom - padded.top} }
		result = blur_filter_result(result, desired, sx[i], sy[i]) or { return false }
	}
	target.ready()
	if !result.has_image {
		draw_empty_filter_result(mut pixels, pitch, &rc, mode)
		return true
	}
	pending << post_color
	draw_color_filtered_bitmap(mut pixels, pitch, result.color_info.bitmap(result.image.bitmap()), base_x + result.origin_x,
		base_y + result.origin_y, &rc, mode, pending, result.color_info.alpha)
	return true
}
