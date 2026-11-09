module cpuraster

// Mixed blur and shadow nodes share the saved source device. Request bounds
// propagate backwards; each shadow merge and real blur retains its own pixels.
fn draw_spatial_filter_chain(mut pixels []u8, width int, height int, pitch int, alpha_type int, transform [6]f32, clips []Path, content_bounds ?Rect, quick_bounds ?Rect, stages []LayerFilterStage, post_color []MatrixColorFilter, source_info FilterImageInfo, source_image bool, source_padding bool, source_per_request bool, source_foreground ?FilterImageView, source_reset ?FilterImageView, source_layer_bounds ?IRect, mode BlendMode, content LayerContent) bool {
	// Bound both backwards requests and evaluation of the branching graph.
	mut work := 1
	for stage in stages {
		work = if stage.kind == .drop_shadow { 2 * work + 1 } else { work + 1 }
		if work > 256 { return false }
	}
	ctm := canvas_affine(transform)
	if ctm.kx != 0 || ctm.ky != 0 { return false }
	mut sx := []f32{cap: stages.len}
	mut sy := []f32{cap: stages.len}
	mut offsets := []SkAffine{cap: stages.len}
	inverse := affine_invert(ctm) or { SkAffine{} }
	for stage in stages {
		valid := stage.sigma >= 0 && is_finite_f32(stage.sigma)
		if !valid && stage.kind != .drop_shadow { return false }
		x := if valid { blur_layer_sigma(math_abs32(stage.sigma * ctm.sx)) } else { f32(0) }
		y := if valid { blur_layer_sigma(math_abs32(stage.sigma * ctm.sy)) } else { f32(0) }
		if x > image_blur_max_sigma || y > image_blur_max_sigma { return false }
		offset := sk_concat(ctm, post_translate(inverse, stage.offset_x, stage.offset_y))
		if !affine_is_finite(offset) || math_abs32(offset.tx) > 1 << 24 || math_abs32(offset.ty) > 1 << 24 { return false }
		sx << x
		sy << y
		offsets << offset
	}
	mut target := new_canvas_target(mut pixels, width, height, pitch, alpha_type)
	rc := canvas_raster_clip(width, height, clips)
	if bounds := quick_bounds {
		mut fast := bounds
		for stage in stages {
			valid := stage.sigma >= 0 && is_finite_f32(stage.sigma)
			pad := if valid { f32(3) * stage.sigma } else { f32(0) }
			base := if valid { fast } else { bounds }
			mut expanded := Rect{base.left - pad, base.top - pad, base.right + pad, base.bottom + pad}
			if stage.kind == .drop_shadow {
				expanded = Rect{expanded.left + stage.offset_x, expanded.top + stage.offset_y,
					expanded.right + stage.offset_x, expanded.bottom + stage.offset_y}
				if !rect_is_empty(fast) && !rect_is_empty(expanded) {
					expanded = Rect{fmin_std(fast.left, expanded.left), fmin_std(fast.top, expanded.top),
						fmax_std(fast.right, expanded.right), fmax_std(fast.bottom, expanded.bottom)}
				} else if !rect_is_empty(fast) { expanded = fast }
			}
			fast = expanded
		}
		if canvas_quick_reject(fast, affine_to_matrix(ctm), &rc) { return target.ready() }
	}
	if rc.is_empty || ctm.sx == 0 || ctm.sy == 0 || !affine_is_finite(ctm) { return target.ready() }
	output := rc.bounds()
	device_bounds := filter_layer_source_bounds(content_bounds, source_layer_bounds, ctm)
	requests := SpatialFilterGraph{stages: stages, sx: sx, sy: sy, offsets: offsets,
		content_bounds: device_bounds}
	layer := requests.input_bounds(stages.len - 1, output) or { return false }
	if layer.is_empty() {
		target.ready()
		draw_empty_filter_result(mut pixels, pitch, &rc, mode)
		return true
	}
	max_dim := math_max_int(2 * math_max_int(output.width(), output.height()), 2048)
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
	if !source_per_request && !content(mut layer_pixels, lw, lh, layer_transform, [inner_clip]) { return false }
	mut result := FilterResult{...new_filter_result(SpecialImage{BlurImage{layer_pixels, lw, lh},
		IRect{0, 0, lw, lh}}, 0, 0).inset_for_save_layer(), color_info: source_info,
		transparent_boundary: !source_image || source_padding}
	local := canvas_affine(layer_transform)
	local_inverse := affine_invert(local) or { return false }
	for i, stage in stages {
		if !source_image { offsets[i] = sk_concat(local, post_translate(local_inverse, stage.offset_x, stage.offset_y)) }
	}
	base_x, base_y := if source_image { 0 } else { padded.left }, if source_image { 0 } else { padded.top }
	if source_image { result = result.translated(padded.left, padded.top) }
	desired := if source_image { output } else { IRect{output.left - padded.left, output.top - padded.top,
		output.right - padded.left, output.bottom - padded.top} }
	mut resolve_at := -1
	if source_per_request {
		for i in 0 .. stages.len {
			if stages[i].kind == .drop_shadow || sx[i] != 0 || sy[i] != 0 { resolve_at = i; break }
		}
	}
	graph := SpatialFilterGraph{stages: stages, sx: sx, sy: sy, offsets: offsets,
		source: result, max_dim: max_dim, resolve_at: resolve_at, content: content,
		source_transform: transform, source_bounds: device_bounds or { layer }, source_view: source_foreground,
		reset_view: source_reset}
	value := graph.evaluate(stages.len - 1, desired) or { return false }
	result = value.image
	mut pending := value.color.clone()

	target.ready()
	if !result.has_image {
		draw_empty_filter_result(mut pixels, pitch, &rc, mode)
		return true
	}
	pending << post_color
	draw_color_filtered_bitmap(mut pixels, pitch, result.color_info.bitmap(result.image.bitmap()),
		base_x + result.origin_x, base_y + result.origin_y, &rc, mode, pending, result.color_info.alpha)
	return true
}

fn spatial_filter_resolve_color(result FilterResult, filter ?ColorFilter) FilterResult {
	return FilterResult{...result, image: SpecialImage{
		filter_layer_source_image(result.image.backing, result.color_info, filter), result.image.subset},
		color_info: FilterImageInfo{}}
}

// A shadow forks its input graph. The foreground and blurred branch evaluate
// earlier nodes with different desired bounds, so a union-sized intermediate
// cannot stand in for both native evaluations.
struct SpatialFilterValue {
	image FilterResult
	color []MatrixColorFilter
	view ?FilterImageView
}

struct SpatialFilterGraph {
	stages []LayerFilterStage
	sx []f32
	sy []f32
	offsets []SkAffine
	source FilterResult
	max_dim int
	content_bounds ?IRect
	resolve_at int = -1
	content LayerContent = unsafe { nil }
	source_transform [6]f32
	source_bounds IRect
	source_view ?FilterImageView
	reset_view ?FilterImageView
}

// Known content bounds apply at each SourceGraphic leaf before unions.
fn (g &SpatialFilterGraph) input_bounds(index int, desired IRect) ?IRect {
	if desired.is_empty() { return IRect{} }
	if index < 0 {
		return if bounds := g.content_bounds { desired.intersect(bounds) or { IRect{} } } else { desired }
	}
	stage := g.stages[index]
	rx, ry := skif_ceil(f32(3) * g.sx[index]), skif_ceil(f32(3) * g.sy[index])
	if stage.kind == .blur { return g.input_bounds(index - 1, skif_outset(desired, rx, ry)) }
	shadow := skif_outset(map_filter_bounds(desired, affine_invert(g.offsets[index]) or { return none }), 1, 1)
	child_index := if stage.sigma < 0 || !is_finite_f32(stage.sigma) { -1 } else { index - 1 }
	return union_filter_bounds(g.input_bounds(index - 1, desired)?,
		g.input_bounds(child_index, skif_outset(shadow, rx, ry))?)
}

fn (g &SpatialFilterGraph) evaluate(index int, desired IRect) ?SpatialFilterValue {
	if desired.is_empty() { return SpatialFilterValue{} }
	if index < 0 { return SpatialFilterValue{image: g.source, view: g.source_view} }
	stage := g.stages[index]
	if index == g.resolve_at && stage.kind == .blur { return g.resolve_source_blur(index, desired) }
	rx, ry := skif_ceil(f32(3) * g.sx[index]), skif_ceil(f32(3) * g.sy[index])
	if stage.kind == .blur {
		needed := skif_outset(desired, rx, ry)
		child := spatial_filter_apply_color(g.evaluate(index - 1, needed)?, stage.pre_color, needed)
		return spatial_filter_blur(child, desired, g.sx[index], g.sy[index])
	}
	foreground := spatial_filter_apply_color(g.evaluate(index - 1, desired)?, stage.pre_color, desired)
	offset := g.offsets[index]
	shadow_desired := skif_outset(map_filter_bounds(desired, affine_invert(offset) or { return none }), 1, 1)
	needed := skif_outset(shadow_desired, rx, ry)
	shadow := if stage.sigma < 0 || !is_finite_f32(stage.sigma) {
		// Blur() rejects this node and its input; the tint then reads
		// SourceGraphic while the foreground still evaluates earlier nodes.
		SpatialFilterValue{image: g.source, view: g.reset_view}
	} else if index == g.resolve_at && (g.sx[index] != 0 || g.sy[index] != 0) {
		g.resolve_source_blur(index, shadow_desired)?
	} else {
		child := spatial_filter_apply_color(g.evaluate(index - 1, needed)?, stage.pre_color, needed)
		spatial_filter_blur(child, shadow_desired, g.sx[index], g.sy[index])?
	}
	return spatial_filter_merge(foreground, shadow, offset, desired, stage.color, g.max_dim)
}

// Rescale resolves a deferred source per blur request. Clamping and the
// strict subset sampler depend on that request's visible input rectangle.
fn (g &SpatialFilterGraph) resolve_source_blur(index int, desired IRect) ?SpatialFilterValue {
	rx, ry := skif_ceil(f32(3) * g.sx[index]), skif_ceil(f32(3) * g.sy[index])
	output := desired.intersect(skif_outset(g.source_bounds, rx, ry)) or { return SpatialFilterValue{} }
	requested := skif_outset(output, rx, ry)
	if view := g.source_view {
		if source := raw_filter_image_view(view, requested) {
			return SpatialFilterValue{image: blur_filter_result(source, desired, g.sx[index], g.sy[index])?}
		}
	}
	visible := g.source_bounds.intersect(requested) or { return SpatialFilterValue{} }
	padded := skif_outset(visible, 1, 1)
	w, h := padded.width(), padded.height()
	if w > g.max_dim || h > g.max_dim || w > max_untiled_dimension || h > max_untiled_dimension { return none }
	mut pixels := []u8{len: w * h * 4}
	ctm := canvas_affine(g.source_transform)
	left, top := f32(padded.left), f32(padded.top)
	zero_x, zero_y := -left * f32(0), -top * f32(0)
	shift_x, shift_y := -left * f32(1), -top * f32(1)
	transform := [zero_x + ctm.sx, zero_y + ctm.ky, zero_x + ctm.kx,
		zero_y + ctm.sy, shift_x + ctm.tx, shift_y + ctm.ty]!
	clip := rect_path(Rect{1, 1, f32(w - 1), f32(h - 1)})
	if !g.content(mut pixels, w, h, transform, [clip]) { return none }
	source := new_filter_result(SpecialImage{BlurImage{pixels, w, h}, IRect{0, 0, w, h}},
		padded.left, padded.top).inset_for_save_layer()
	return SpatialFilterValue{image: blur_filter_result(source, desired, g.sx[index], g.sy[index])?}
}

fn spatial_filter_apply_color(value SpatialFilterValue, matrices []MatrixColorFilter, desired IRect) SpatialFilterValue {
	if new_color_filter(matrices) == none { return value }
	if !value.image.has_image || !irect_intersects(value.image.layer_bounds, desired) { return SpatialFilterValue{} }
	mut color := value.color.clone()
	color << matrices
	return SpatialFilterValue{image: value.image, color: color}
}

fn spatial_filter_blur(value SpatialFilterValue, desired IRect, sx f32, sy f32) ?SpatialFilterValue {
	if !value.image.has_image { return SpatialFilterValue{} }
	if sx == 0 && sy == 0 { return value }
	mut input := value.image
	filter := new_color_filter(value.color)
	if filter != none || input.color_info.display_p3 || input.color_info.alpha != 1 {
		input = spatial_filter_resolve_color(input, filter)
	}
	return SpatialFilterValue{image: blur_filter_result(input, desired, sx, sy)?}
}

fn spatial_filter_merge(foreground SpatialFilterValue, shadow SpatialFilterValue, offset SkAffine, desired IRect, color u32, max_dim int) ?SpatialFilterValue {
	// applyTransform() drops nonintersecting shadow results before merge.
	deferred := if view := shadow.view {
		?DeferredImageShadow(prepare_deferred_image_shadow(view, offset, desired, color, true)?)
	} else { none }
	shadow_bounds := if view := deferred { view.bounds }
		else if shadow.image.has_image { map_filter_bounds(shadow.image.layer_bounds, offset) } else { IRect{} }
	has_shadow := irect_intersects(shadow_bounds, desired)
	foreground_bounds := if view := foreground.view {
		if view.filter == none || irect_intersects(view.layer_bounds, desired) { view.layer_bounds } else { IRect{} }
	} else if foreground.image.has_image { foreground.image.layer_bounds } else { IRect{} }
	bounds := union_filter_bounds(foreground_bounds,
		if has_shadow { shadow_bounds } else { IRect{} })
	merged_bounds := bounds.intersect(desired) or { return SpatialFilterValue{} }
	padded := skif_outset(merged_bounds, 1, 1)
	w, h := padded.width(), padded.height()
	if w > max_dim || h > max_dim || w > max_untiled_dimension || h > max_untiled_dimension { return none }
	mut pixels := []u8{len: w * h * 4}
	rc := canvas_raster_clip(w, h, [rect_path(Rect{1, 1, f32(w - 1), f32(h - 1)})])
	if has_shadow {
		if view := deferred {
			mut target := new_canvas_target(mut pixels, w, h, w * 4, 2)
			if !draw_prepared_image_shadow(mut pixels, w * 4, &rc, view, padded.left, padded.top, mut target) { return none }
		} else {
			draw_tinted_filter_result_with_color(mut pixels, w * 4, shadow.image, offset, padded.left, padded.top,
				&rc, color, shadow.color)
		}
	}
	if view := foreground.view {
		mut target := new_canvas_target(mut pixels, w, h, w * 4, 2)
		if !foreground_bounds.is_empty() && !draw_filter_image_view(mut pixels, w * 4, &rc,
			.src_over, view, padded.left, padded.top, mut target) { return none }
	} else if foreground.image.has_image {
		image := foreground.image
		draw_color_filtered_bitmap(mut pixels, w * 4, image.color_info.bitmap(image.image.bitmap()),
			image.origin_x - padded.left, image.origin_y - padded.top, &rc, .src_over, foreground.color,
			image.color_info.alpha)
	}
	return SpatialFilterValue{image: new_filter_result(SpecialImage{BlurImage{pixels, w, h}, IRect{0, 0, w, h}},
		padded.left, padded.top).inset_for_save_layer()}
}
