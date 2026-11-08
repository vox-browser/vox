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
pub:
	kind     CanvasFilterKind
	matrix   MatrixColorFilter
	sigma    f32
	offset_x f32
	offset_y f32
	color    u32
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
// are not a scale and translation, blenders that affect transparent
// black, sigmas above the raster blur's 135, layers past the maximum
// dimension and content the inner draw declines.
// DropShadow is Blur -> SrcIn color filter -> offset, merged under the source.
// The color filter stays deferred until sampling, just as in FilterResult.
fn draw_filter_layer(mut pixels []u8, width int, height int, pitch int, alpha_type int, transform [6]f32, clips []Path, content_bounds Rect, step CanvasFilterStep, mode BlendMode, content LayerContent) bool {
	// An invalid DropShadow blur becomes a null child, leaving the tint,
	// offset and merge on SourceGraphic. A lone invalid blur is discarded
	// by new_canvas_filter().
	sigma := if step.sigma >= 0 && is_finite_f32(step.sigma) { step.sigma } else { f32(0) }
	ctm := canvas_affine(transform)
	if ctm.kx != 0 || ctm.ky != 0 || blend_affects_transparent_black(mode) {
		return false
	}
	drop := step.kind == .drop_shadow
	// Scaled shadow layers need the remaining FilterResult resampling and
	// crop analysis. Preserve the native fallback until those are ported.
	if drop && (ctm.sx != 1 || ctm.sy != 1) {
		return false
	}
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
	content_device := skif_round_out(map_rect_affine(content_bounds, Matrix{ctm.sx, 0, 0, ctm.sy, ctm.tx, ctm.ty}))
	mut needed := skif_outset(output, rx, ry)
	if drop {
		shifted := skif_outset(map_filter_bounds(output, affine_invert(mapped_offset) or { return false }), 1, 1)
		foreground_input := output.intersect(content_device) or { IRect{} }
		shadow_input := skif_outset(shifted, rx, ry).intersect(content_device) or { IRect{} }
		needed = union_filter_bounds(foreground_input, shadow_input)
	}
	layer := needed.intersect(content_device) or {
		// An empty layer filters an empty source: nothing to draw.
		return target.ready()
	}
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
	layer_image := BlurImage{layer_pixels, lw, lh}
	source := new_filter_result(SpecialImage{layer_image, IRect{0, 0, lw, lh}}, 0, 0).inset_by_pixel()
	desired := IRect{output.left - padded.left, output.top - padded.top, output.right - padded.left, output.bottom - padded.top}
	if drop {
		// internalDrawDeviceWithFilter evaluates in the source device's
		// coordinate system, using localToSrc rather than the parent CTM.
		local := canvas_affine(layer_transform)
		local_inverse := affine_invert(local) or { return true }
		local_offset := sk_concat(local, post_translate(local_inverse, step.offset_x, step.offset_y))
		shadow_desired := skif_outset(map_filter_bounds(desired, affine_invert(local_offset) or { return true }), 1, 1)
		shadow := blur_filter_result(source, shadow_desired, sx, sy) or { return true }
		mut merged_bounds := if shadow.has_image {
			union_filter_bounds(source.layer_bounds, map_filter_bounds(shadow.layer_bounds, local_offset))
		} else {
			source.layer_bounds
		}
		merged_bounds = merged_bounds.intersect(desired) or { return true }
		mw := merged_bounds.width()
		mh := merged_bounds.height()
		mut merged := []u8{len: mw * mh * 4}
		merge_clip := canvas_raster_clip(mw, mh, [])
		if shadow.has_image {
			draw_tinted_filter_result(mut merged, mw * 4, shadow, local_offset,
				merged_bounds.left, merged_bounds.top, &merge_clip, step.color)
		}
		draw_filter_sprite(mut merged, mw * 4, source.image.bitmap(), source.origin_x - merged_bounds.left,
			source.origin_y - merged_bounds.top, &merge_clip, .src_over)
		draw_filter_sprite(mut pixels, pitch, BlurImage{merged, mw, mh}, padded.left + merged_bounds.left,
			padded.top + merged_bounds.top, &rc, mode)
		return true
	}
	result := blur_filter_result(source, desired, sx, sy) or { return true }
	if !result.has_image || desired.is_empty() {
		return true
	}
	// FilterResult::draw(): a pixel-aligned image is a sprite at the layer
	// origin, drawn with the blender at full alpha through the clip.
	image := result.image.bitmap()
	ix := padded.left + result.origin_x
	iy := padded.top + result.origin_y
	draw_filter_sprite(mut pixels, pitch, image, ix, iy, &rc, mode)
	return true
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
	// The transparent boundary is sampled before the color filter. Retain
	// the backing's padding (which can contain pixels beyond a soft crop).
	subset := skif_outset(result.image.subset, 1, 1)
	assert IRect{0, 0, result.image.backing.width, result.image.backing.height}.contains(subset)
	image := SpecialImage{result.image.backing, subset}.bitmap()
	// applyTransform(), Concat(device, result), then preTranslate(-1).
	transformed := sk_concat(mapped, affine_translate(f32(result.origin_x), f32(result.origin_y)))
	net := sk_concat(affine_translate(-f32(origin_x), -f32(origin_y)), transformed)
	total := pre_translate(net, -1, -1)
	bitmap := CanvasBitmap{ pixels: image.pixels, width: image.width, height: image.height, pitch: image.width * 4, premultiplied: true }
	shader := new_image_shader(bitmap, .clamp, .clamp, true, total)
	base := new_image_blitter(mut pixels, pitch, shader.image, 1, .src_over)
	a := f32(color >> 24) * inv_255
	tint := [f32((color >> 16) & 255) * inv_255 * a, f32((color >> 8) & 255) * inv_255 * a,
		f32(color & 255) * inv_255 * a, a]!
	mut blitter := PipelineBlitter{ ...base, tinted: true, tint: tint, lowp_tint: tint.map(lowp_from_float(it)) }
	bounds := map_filter_bounds(result.layer_bounds, mapped)
	fill_irect(IRect{bounds.left - origin_x, bounds.top - origin_y, bounds.right - origin_x, bounds.bottom - origin_y}, rc, mut blitter)
}

// SkBitmapDevice::drawSpecial() of a pixel-aligned filter result:
// Draw::drawBitmap()'s sprite blitters when the clip handles the sprite,
// otherwise its rect filled with the nearest clamped image shader.
fn draw_filter_sprite(mut pixels []u8, pitch int, image BlurImage, x int, y int, rc &RasterClip, mode BlendMode) {
	bounds := IRect{x, y, x + image.width, y + image.height}
	if !irect_intersects(rc.bounds(), bounds) {
		return
	}
	bitmap := CanvasBitmap{
		pixels:        image.pixels
		width:         image.width
		height:        image.height
		pitch:         image.width * 4
		premultiplied: true
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
