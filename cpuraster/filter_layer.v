module cpuraster

// Canvas2D filter lists as make_filter() builds them, and the image filter
// layer SkCanvas draws a filtered paint through: AutoLayerForImageFilter
// saves a layer sized by get_layer_mapping_and_bounds(), the draw renders
// into it with the paint's own color, shader and alpha, and the restore
// filters the layer (SkCanvas::internalDrawDeviceWithFilter()) and draws
// the result back with the paint's blender inside the canvas clip.

pub enum CanvasFilterKind {
	matrix
	blur
}

// CanvasFilterStep is one canvas filter function: a color matrix, or a
// blur whose radius is its sigma.
pub struct CanvasFilterStep {
pub:
	kind   CanvasFilterKind
	matrix MatrixColorFilter
	sigma  f32
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

// A list that is exactly one blur: its sigma.
fn (f CanvasFilter) single_blur() ?f32 {
	if f.steps.len == 1 && f.steps[0].kind == .blur {
		return f.steps[0].sigma
	}
	return none
}

// How a draw applies its canvas filters: a color filter in the paint, or
// a blur layer; declined lists are neither.
struct FilterPlan {
	color    ?ColorFilter
	blur     f32 = -1
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
	if sigma := f.single_blur() {
		return FilterPlan{
			blur: sigma
		}
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

// draw_blur_layer draws content through an SkImageFilters::Blur(sigma)
// layer: content_bounds are the draw's local fast bounds. Returns false,
// before touching the pixels, for what is not ported: transforms that
// are not a scale and translation, blenders that affect transparent
// black, sigmas above the raster blur's 135, layers past the maximum
// dimension and content the inner draw declines.
fn draw_blur_layer(mut pixels []u8, width int, height int, pitch int, alpha_type int, transform [6]f32, clips []Path, content_bounds Rect, sigma f32, mode BlendMode, content LayerContent) bool {
	ctm := canvas_affine(transform)
	if ctm.kx != 0 || ctm.ky != 0 || blend_affects_transparent_black(mode) {
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
	needed := skif_outset(output, rx, ry)
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
