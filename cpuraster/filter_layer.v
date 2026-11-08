module cpuraster

import math

// Canvas2D filter lists as make_filter() builds them, and the image filter
// layer SkCanvas draws a filtered paint through: AutoLayerForImageFilter
// saves a layer sized by get_layer_mapping_and_bounds(), the draw renders
// into it with the paint's own color, shader and alpha, and the restore
// filters the layer (SkCanvas::internalDrawDeviceWithFilter()) and draws
// the result back with the paint's blender inside the canvas clip.

pub enum CanvasFilterKind {
	matrix
	blur
	drop_shadow
}

// CanvasFilterStep is one canvas filter function. Blur and drop-shadow
// radii are Gaussian sigmas; offsets are in canvas coordinates.
pub struct CanvasFilterStep {
	blur_stages []BlurFilterStage
	source_image bool
	source_padding bool
	source_color_info FilterImageInfo
	pre_color []MatrixColorFilter
	post_color []MatrixColorFilter
pub:
	kind     CanvasFilterKind
	matrix   MatrixColorFilter
	sigma    f32
	offset_x f32
	offset_y f32
	color    u32
}

// A blur's incoming color filters remain deferred through identity passes.
struct BlurFilterStage {
	sigma f32
	pre_color []MatrixColorFilter
}

pub struct CanvasFilter {
pub:
	steps []CanvasFilterStep
}

// new_canvas_filter keeps the steps make_filter() keeps: a blur that
// SkImageFilters::Blur() rejects (a negative or non-finite sigma) returns
// null and so drops everything before it. None when nothing remains.
pub fn new_canvas_filter(steps []CanvasFilterStep) ?CanvasFilter {
	mut kept := []CanvasFilterStep{}
	for step in steps {
		if step.kind == .blur && (!is_finite_f32(step.sigma) || step.sigma < 0) {
			kept.clear()
			continue
		}
		kept << step
	}
	if kept.len == 0 {
		return none
	}
	return CanvasFilter{kept}
}

// canvas_matrix_filter is a list of color matrices as a CanvasFilter.
pub fn canvas_matrix_filter(matrices []MatrixColorFilter) ?CanvasFilter {
	return new_canvas_filter(matrices.map(CanvasFilterStep{
		kind:   .matrix
		matrix: it
	}))
}

// The paint's color filter when every step is a matrix (ImageToColorFilter()
// then applies): whether it is, and the composed filter.
fn (f CanvasFilter) color_only() (bool, ?ColorFilter) {
	mut matrices := []MatrixColorFilter{}
	for step in f.steps {
		if step.kind != .matrix {
			return false, none
		}
		matrices << step.matrix
	}
	return true, new_color_filter(matrices)
}

// How a draw applies its canvas filters: a color filter in the paint, or
// a blur/drop-shadow layer; declined lists are neither.
struct FilterPlan {
	color    ?ColorFilter
	layer    ?CanvasFilterStep
	declined bool
}

fn plan_canvas_filter(filter ?CanvasFilter) FilterPlan {
	f := filter or { return FilterPlan{} }
	only, color := f.color_only()
	if only {
		if c := color {
			if c.affects_transparent_black() {
				return FilterPlan{
					declined: true
				}
			}
		}
		return FilterPlan{
			color: color
		}
	}
	if f.steps.len == 1 && f.steps[0].kind in [.blur, .drop_shadow] {
		return FilterPlan{ layer: f.steps[0] }
	}
	if f.steps.filter(it.kind == .blur).len > 1 && f.steps.all(it.kind in [.blur, .matrix]) {
		mut stages := []BlurFilterStage{}
		mut matrices := []MatrixColorFilter{}
		for step in f.steps {
			if step.kind == .matrix {
				matrices << step.matrix
				continue
			}
			if incoming_color := new_color_filter(matrices) {
				if incoming_color.affects_transparent_black() { return FilterPlan{declined: true} }
			}
			stages << BlurFilterStage{step.sigma, matrices.clone()}
			matrices.clear()
		}
		if final_color := new_color_filter(matrices) {
			if final_color.affects_transparent_black() { return FilterPlan{declined: true} }
		}
		return FilterPlan{layer: CanvasFilterStep{kind: .blur, sigma: stages.last().sigma,
			blur_stages: stages, post_color: matrices}}
	}
	mut layer_index := -1
	for i, step in f.steps {
		if step.kind == .matrix { continue }
		if layer_index >= 0 { return FilterPlan{declined: true} }
		layer_index = i
	}
	if layer_index >= 0 {
		step := f.steps[layer_index]
		mut before := []MatrixColorFilter{}
		mut after := []MatrixColorFilter{}
		for i, matrix in f.steps {
			if i < layer_index { before << matrix.matrix }
			if i > layer_index { after << matrix.matrix }
		}
		for matrices in [before, after] {
			if composed := new_color_filter(matrices) {
				if composed.affects_transparent_black() { return FilterPlan{declined: true} }
			}
		}
		return FilterPlan{layer: CanvasFilterStep{...step, pre_color: before, post_color: after}}
	}
	return FilterPlan{
		declined: true
	}
}

// SkBlenderBase::affectsTransparentBlack(): a Porter-Duff mode whose
// destination coefficient is not one, 1 - source alpha or 1 - source
// color, or a runtime blender. Those fill the clip on restore.
fn blend_affects_transparent_black(mode BlendMode) bool {
	return mode in [.clear, .src, .src_in, .dst_in, .src_out, .dst_atop, .plus_darker, .plus_lighter]
}

// The content a filter layer holds, drawn by the original command into
// the layer: its pixels (premultiplied, rows packed), the layer's
// transform and its padding clip.
type LayerContent = fn (mut layer []u8, width int, height int, transform [6]f32, clips []Path) bool

// RoundOut() of skif: inset by the rounding epsilon, then rounded out.
fn skif_round_out(r Rect) IRect {
	e := image_filter_round_epsilon
	return round_out(Rect{r.left + e, r.top + e, r.right - e, r.bottom - e})
}

// draw_filter_layer draws content through a blur or drop-shadow
// layer: content_bounds are the draw's local fast bounds. Returns false,
// before touching the pixels, for what is not ported: transforms that
// are not a scale and translation, sigmas above the raster blur's 135,
// layers past the maximum
// dimension and content the inner draw declines.
// DropShadow is Blur -> SrcIn color filter -> offset, merged under the source.
// The color filter stays deferred until sampling, just as in FilterResult.
fn draw_filter_layer(mut pixels []u8, width int, height int, pitch int, alpha_type int, transform [6]f32, clips []Path, content_bounds Rect, step CanvasFilterStep, mode BlendMode, content LayerContent) bool {
	return draw_filter_layer_tinted(mut pixels, width, height, pitch, alpha_type, transform,
		clips, content_bounds, step, mode, content, none)
}

fn draw_filter_layer_tinted(mut pixels []u8, width int, height int, pitch int, alpha_type int, transform [6]f32, clips []Path, content_bounds ?Rect, step CanvasFilterStep, mode BlendMode, content LayerContent, tint ?u32) bool {
	if step.blur_stages.len > 0 {
		return draw_blur_filter_chain(mut pixels, width, height, pitch, alpha_type,
			transform, clips, content_bounds, step.blur_stages, step.post_color, step.source_color_info,
			step.source_image, step.source_padding, mode, content)
	}
	// An invalid DropShadow blur becomes a null child, leaving the tint,
	// offset and merge on SourceGraphic. A lone invalid blur is discarded
	// by new_canvas_filter().
	sigma := if step.sigma >= 0 && is_finite_f32(step.sigma) { step.sigma } else { f32(0) }
	ctm := canvas_affine(transform)
	if ctm.kx != 0 || ctm.ky != 0 {
		return false
	}
	drop := step.kind == .drop_shadow
	// Mapping::paramToLayer(matrix) conjugates the offset. Float inverse
	// and concat arithmetic can retain a tiny scale; keep it for sampling.
	inverse := affine_invert(ctm) or { SkAffine{} }
	mapped_offset := sk_concat(ctm, post_translate(inverse, step.offset_x, step.offset_y))
	dx := mapped_offset.tx
	dy := mapped_offset.ty
	if drop && (!is_finite_f32(dx) || !is_finite_f32(dy) || math_abs32(dx) > 1 << 24 || math_abs32(dy) > 1 << 24) {
		return false
	}
	// Mapping::paramToLayer() of the sigma: the scale's basis vectors.
	sx := f32(math_abs32(sigma * ctm.sx))
	sy := f32(math_abs32(sigma * ctm.sy))
	layer_sx := blur_layer_sigma(sx)
	layer_sy := blur_layer_sigma(sy)
	if layer_sx > image_blur_max_sigma || layer_sy > image_blur_max_sigma {
		return false
	}
	mut target := new_canvas_target(mut pixels, width, height, pitch, alpha_type)
	rc := canvas_raster_clip(width, height, clips)
	if bounds := content_bounds {
		// The draw's quick reject precedes aboutToDraw()/saveLayer(). Its
		// fast bounds use the parameter-space filter radius, even when the
		// mapped blur later becomes an identity.
		pad := f32(3) * sigma
		mut fast := Rect{bounds.left - pad, bounds.top - pad, bounds.right + pad, bounds.bottom + pad}
		if drop {
			fast = Rect{fast.left + step.offset_x, fast.top + step.offset_y,
				fast.right + step.offset_x, fast.bottom + step.offset_y}
			// Merge's computeFastBounds uses SkRect::join(), which ignores
			// the empty original bounds of move-only/degenerate paths.
			if !rect_is_empty(bounds) {
				fast = if rect_is_empty(fast) { bounds } else {
					Rect{fmin_std(bounds.left, fast.left), fmin_std(bounds.top, fast.top),
						fmax_std(bounds.right, fast.right), fmax_std(bounds.bottom, fast.bottom)}
				}
			}
		}
		if canvas_quick_reject(fast, affine_to_matrix(ctm), &rc) { return target.ready() }
	}
	// internalSaveLayer(): nothing in an empty clip, and a non-invertible
	// matrix aborts the layer.
	if rc.is_empty || ctm.sx == 0 || ctm.sy == 0 || !affine_is_finite(ctm) {
		return target.ready()
	}
	output := rc.bounds()
	// get_layer_mapping_and_bounds(): the layer space is the device space;
	// the blur needs the clip bounds outset by its kernel, cut to the
	// content's rounded-out bounds.
	rx := skif_ceil(f32(3) * layer_sx)
	ry := skif_ceil(f32(3) * layer_sy)
	mut needed := skif_outset(output, rx, ry)
	content_device := if bounds := content_bounds {
		skif_round_out(map_rect_affine(bounds, Matrix{ctm.sx, 0, 0, ctm.sy, ctm.tx, ctm.ty}))
	} else { needed }
	if drop {
		shifted := skif_outset(map_filter_bounds(output, affine_invert(mapped_offset) or { return false }), 1, 1)
		foreground_input := if content_bounds == none { output } else {
			output.intersect(content_device) or { IRect{} }
		}
		shadow_needed := skif_outset(shifted, rx, ry)
		shadow_input := if content_bounds == none { shadow_needed } else {
			shadow_needed.intersect(content_device) or { IRect{} }
		}
		needed = union_filter_bounds(foreground_input, shadow_input)
	}
	layer := if content_bounds == none { needed } else { needed.intersect(content_device) or {
		// An empty source still restores through a transparency-affecting
		// blender (internalSaveLayer's null-source filter evaluation).
		target.ready()
		draw_empty_filter_result(mut pixels, pitch, &rc, mode)
		return true
	} }
	max_dim := math_max_int(2 * math_max_int(output.width(), output.height()), 2048)
	if layer.width() > max_dim || layer.height() > max_dim {
		return false
	}
	// The padded layer: one transparent pixel around the content.
	padded := skif_outset(layer, 1, 1)
	lw := padded.width()
	lh := padded.height()
	if lw > max_untiled_dimension || lh > max_untiled_dimension {
		return false
	}
	mut layer_pixels := []u8{len: lw * lh * 4}
	// setDeviceCoordinateSystem(): the layer matrix post-translated by the
	// buffer origin in SkM44 floats.
	left := f32(padded.left)
	top := f32(padded.top)
	// SkM44::postTranslate(): t * column.w + column per column.
	zero_x := -left * f32(0)
	zero_y := -top * f32(0)
	shift_x := -left * f32(1)
	shift_y := -top * f32(1)
	layer_transform := [zero_x + ctm.sx, zero_y + ctm.ky, zero_x + ctm.kx, zero_y + ctm.sy, shift_x +
		ctm.tx, shift_y + ctm.ty]!
	inner_clip := rect_path(Rect{1, 1, f32(lw - 1), f32(lh - 1)})
	if !content(mut layer_pixels, lw, lh, layer_transform, [inner_clip]) {
		return false
	}
	target.ready()
	// internalDrawDeviceWithFilter(): the layer without its padding, the
	// clip bounds in layer pixels as the desired output.
	mut layer_image := BlurImage{layer_pixels, lw, lh}
	original_layer_image := layer_image
	mut layer_info := step.source_color_info
	mut restore_matrices := step.post_color.clone()
	if step.pre_color.len > 0 {
		if !drop && layer_sx == 0 && layer_sy == 0 {
			// An identity blur preserves the deferred color filter. Compose
			// both sides without an intermediate 8-bit quantization.
			restore_matrices = step.pre_color.clone()
			restore_matrices << step.post_color
		}
	}
	incoming_color := new_color_filter(step.pre_color)
	if (layer_sx != 0 || layer_sy != 0) && (incoming_color != none || layer_info.display_p3) {
		layer_image = filter_layer_source_image(layer_image, layer_info, incoming_color)
		layer_info = FilterImageInfo{}
	}
	saved := new_filter_result(SpecialImage{layer_image, IRect{0, 0, lw, lh}}, 0, 0).inset_for_save_layer()
	mut source := FilterResult{...saved, transparent_boundary: !step.source_image || step.source_padding,
		color_info: layer_info}
	base_x := if step.source_image { 0 } else { padded.left }
	base_y := if step.source_image { 0 } else { padded.top }
	if step.source_image { source = source.translated(padded.left, padded.top) }
	desired := if step.source_image { output } else {
		IRect{output.left - padded.left, output.top - padded.top, output.right - padded.left, output.bottom - padded.top} }
	if drop {
		// Preserve the source color filter for the foreground merge. A real
		// shadow blur resolves it, while an identity blur keeps it deferred
		// immediately before the SrcIn tint.
		foreground_saved := new_filter_result(SpecialImage{original_layer_image, IRect{0, 0, lw, lh}}, 0, 0).inset_for_save_layer()
		mut foreground := FilterResult{...foreground_saved, color_info: step.source_color_info}
		if step.source_image { foreground = foreground.translated(padded.left, padded.top) }
		// A rejected blur node has a null child, so this shadow samples
		// SourceGraphic rather than the preceding color-filter result.
		shadow_matrices := if step.sigma >= 0 && is_finite_f32(step.sigma)
			&& layer_sx == 0 && layer_sy == 0 { step.pre_color } else { []MatrixColorFilter{} }
		// internalDrawDeviceWithFilter evaluates in the source device's
		// coordinate system, using localToSrc rather than the parent CTM.
		local := canvas_affine(layer_transform)
		local_inverse := affine_invert(local) or { return true }
		local_offset := if step.source_image { mapped_offset } else {
			sk_concat(local, post_translate(local_inverse, step.offset_x, step.offset_y)) }
		shadow_desired := skif_outset(map_filter_bounds(desired, affine_invert(local_offset) or { return true }), 1, 1)
		shadow := blur_filter_result(source, shadow_desired, sx, sy) or { return true }
		mut merged_bounds := if shadow.has_image {
			union_filter_bounds(foreground.layer_bounds, map_filter_bounds(shadow.layer_bounds, local_offset))
		} else {
			foreground.layer_bounds
		}
		merged_bounds = merged_bounds.intersect(desired) or {
			draw_empty_filter_result(mut pixels, pitch, &rc, mode)
			return true
		}
		// Builder::merge() uses a transparent one-pixel boundary. Its device
		// origin includes that padding before the offset matrix is inverted.
		// Sampling in an unpadded device changes rounding for residual scales
		// introduced by paramToLayer()'s matrix conjugation.
		merge_padded := skif_outset(merged_bounds, 1, 1)
		mw := merge_padded.width()
		mh := merge_padded.height()
		mut merged := []u8{len: mw * mh * 4}
		merge_clip := canvas_raster_clip(mw, mh,
			[rect_path(Rect{1, 1, f32(mw - 1), f32(mh - 1)})])
		if shadow.has_image {
			draw_tinted_filter_result_with_color(mut merged, mw * 4, shadow, local_offset,
				merge_padded.left, merge_padded.top, &merge_clip, step.color, shadow_matrices)
		}
		draw_color_filtered_bitmap(mut merged, mw * 4, foreground.color_info.bitmap(foreground.image.bitmap()), foreground.origin_x - merge_padded.left,
			foreground.origin_y - merge_padded.top, &merge_clip, .src_over, step.pre_color)
		draw_color_filtered_sprite(mut pixels, pitch, BlurImage{merged, mw, mh}, base_x + merge_padded.left,
			base_y + merge_padded.top, &rc, mode, restore_matrices)
		return true
	}
	result := blur_filter_result(source, desired, sx, sy) or { return true }
	if !result.has_image || desired.is_empty() {
		draw_empty_filter_result(mut pixels, pitch, &rc, mode)
		return true
	}
	if color := tint {
		draw_tinted_filter_result(mut pixels, pitch, result, SkAffine{}, -base_x,
			-base_y, &rc, color)
		return true
	}
	// FilterResult::draw(): a pixel-aligned image is a sprite at the layer
	// origin, drawn with the blender at full alpha through the clip.
	image := result.image.bitmap()
	ix := base_x + result.origin_x
	iy := base_y + result.origin_y
	draw_color_filtered_bitmap(mut pixels, pitch, result.color_info.bitmap(image), ix, iy, &rc, mode, restore_matrices)
	return true
}

fn draw_empty_filter_result(mut pixels []u8, pitch int, rc &RasterClip, mode BlendMode) {
	if blend_affects_transparent_black(mode) {
		mut blitter := canvas_blitter(mut pixels, pitch, 0, 0, mode) or { return }
		fill_irect(rc.bounds(), rc, mut blitter)
	}
}

fn union_filter_bounds(a IRect, b IRect) IRect {
	if a.is_empty() { return b }
	if b.is_empty() { return a }
	return IRect{if a.left < b.left { a.left } else { b.left }, if a.top < b.top {
		a.top
	} else {
		b.top
	}, if a.right > b.right { a.right } else { b.right }, if a.bottom > b.bottom {
		a.bottom
	} else {
		b.bottom
	}}
}

fn map_filter_bounds(bounds IRect, m SkAffine) IRect {
	// Mapping::map<SkIRect>() preserves integer precision in doubles.
	l0 := f64(m.sx) * bounds.left
	r0 := f64(m.sx) * bounds.right
	t0 := f64(m.sy) * bounds.top
	b0 := f64(m.sy) * bounds.bottom
	l := l0 + m.tx
	r := r0 + m.tx
	t := t0 + m.ty
	b := b0 + m.ty
	e := f64(image_filter_round_epsilon)
	return IRect{int(math.floor(l + e)), int(math.floor(t + e)), int(math.ceil(r - e)), int(math.ceil(b - e))}
}

fn draw_tinted_filter_result(mut pixels []u8, pitch int, result FilterResult, mapped SkAffine, origin_x int, origin_y int, rc &RasterClip, color u32) {
	draw_tinted_filter_result_with_color(mut pixels, pitch, result, mapped, origin_x, origin_y, rc, color, [])
}

fn draw_tinted_filter_result_with_color(mut pixels []u8, pitch int, result FilterResult, mapped SkAffine, origin_x int, origin_y int, rc &RasterClip, color u32, matrices []MatrixColorFilter) {
	// Saved layers have a transparent border. Blur output only promises
	// initialized padding: draw that subset with AA, without sampling its
	// border as if it were transparent (FilterResult::draw()).
	pad := if result.transparent_boundary { 1 } else { 0 }
	subset := skif_outset(result.image.subset, pad, pad)
	assert IRect{0, 0, result.image.backing.width, result.image.backing.height}.contains(subset)
	image := SpecialImage{result.image.backing, subset}.bitmap()
	// applyTransform(), Concat(device, result), then preTranslate(-1).
	transformed := sk_concat(mapped, affine_translate(f32(result.origin_x), f32(result.origin_y)))
	net := sk_concat(affine_translate(-f32(origin_x), -f32(origin_y)), transformed)
	total := pre_translate(net, -f32(pad), -f32(pad))
	bitmap := result.color_info.bitmap(image)
	shader := new_image_shader(bitmap, .clamp, .clamp, true, total)
	base := new_image_blitter(mut pixels, pitch, shader.image, 1, .src_over)
	a := f32(color >> 24) * inv_255
	tint := [f32((color >> 16) & 255) * inv_255 * a, f32((color >> 8) & 255) * inv_255 * a,
		f32(color & 255) * inv_255 * a, a]!
	mut blitter := PipelineBlitter{ ...base, tinted: true, tint: tint, lowp_tint: tint.map(lowp_from_float(it)) }
	if filter := new_color_filter(matrices) {
		blitter = PipelineBlitter{...blitter, lowp: false, filtered: true, filter: filter}
	}
	bounds := map_filter_bounds(result.layer_bounds, mapped)
	clip := IRect{bounds.left - origin_x, bounds.top - origin_y, bounds.right - origin_x, bounds.bottom - origin_y}
	if result.transparent_boundary {
		fill_irect(clip, rc, mut blitter)
	} else {
		dev := InverseMatrix{total, total.type_mask()}.map_rect(Rect{0, 0, f32(image.width), f32(image.height)})
		visible := rect_intersect(dev, Rect{f32(clip.left), f32(clip.top), f32(clip.right), f32(clip.bottom)}) or { return }
		anti_fill_rect(visible, rc, mut blitter)
	}
}

// SkBitmapDevice::drawSpecial() of a pixel-aligned filter result:
// Draw::drawBitmap()'s sprite blitters when the clip handles the sprite,
// otherwise its rect filled with the nearest clamped image shader.
fn draw_filter_bitmap(mut pixels []u8, pitch int, bitmap CanvasBitmap, x int, y int, rc &RasterClip, mode BlendMode) {
	bounds := IRect{x, y, x + bitmap.width, y + bitmap.height}
	unbounded := blend_affects_transparent_black(mode)
	if !unbounded && !irect_intersects(rc.bounds(), bounds) {
		return
	}
	if unbounded && !bounds.contains(rc.bounds()) {
		// FilterResult::draw() fills the device with a decal image shader
		// when the restore blender changes transparent black. In particular,
		// copy/source-in also update pixels outside the filtered image.
		shader := new_image_shader(bitmap, .decal, .decal, false, affine_translate(f32(x), f32(y)))
		dev := rc.bounds()
		mut blitter := canvas_paint_blitter(mut pixels, pitch, 0xff000000, shader, 1, mode,
			Rect{f32(dev.left), f32(dev.top), f32(dev.right), f32(dev.bottom)}) or { return }
		fill_irect(dev, rc, mut blitter)
		return
	}
	if rc.is_bw || rc.aa.quick_contains(bounds.left, bounds.top, bounds.right, bounds.bottom) {
		if mut sprite := choose_sprite(mut pixels, pitch, bitmap, x, y, 255, 1, mode) {
			fill_irect(bounds, rc, mut sprite)
			return
		}
	}
	shader := new_image_shader(bitmap, .clamp, .clamp, false, affine_translate(f32(x), f32(y)))
	dev := Rect{f32(x), f32(y), f32(bounds.right), f32(bounds.bottom)}
	mut blitter := canvas_paint_blitter(mut pixels, pitch, 0xff000000, shader, 1, mode, dev) or {
		return
	}
	fill_irect(bounds, rc, mut blitter)
}

@[inline]
fn math_abs32(v f32) f32 {
	return if v < 0 { -v } else { v }
}

@[inline]
fn math_max_int(a int, b int) int {
	return if a > b { a } else { b }
}
