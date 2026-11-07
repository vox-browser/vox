module cpuraster

import math

// Canvas2D path fills and strokes, as skia/canvas_raster.cpp's
// vox_skia_canvas_path() draws them with LibWeb Skia for a solid color without
// filters or shadows: writePixels() premultiplies the bitmap,
// SkCanvas::drawPath() fills or strokes the path anti-aliased inside the clip
// with the composite operation's blender, and readPixels() returns the
// premultiplied surface.

// Segments use skia.Path's encoding: 12 floats per segment, kind (0 move,
// 1 line, 2 quad, 3 cubic, 4 SVG arc, 5 close), point, two control points,
// radii, x-axis rotation in radians, large-arc and sweep flags.
pub fn canvas_path(segments []f32, even_odd bool) Path {
	mut b := PathBuilder{}
	for i := 0; i + 11 < segments.len; i += 12 {
		s := segments[i..i + 12]
		match int(s[0]) {
			0 { b.move_to(s[1], s[2]) }
			1 { b.line_to(s[1], s[2]) }
			2 { b.quad_to(s[3], s[4], s[1], s[2]) }
			3 { b.cubic_to(s[3], s[4], s[5], s[6], s[1], s[2]) }
			4 {
				b.arc_to(s[7], s[8], s[9] * f32(180) / f32(3.141592653589793), s[10] != 0,
					s[11] != 0, s[1], s[2])
			}
			5 { b.close() }
			else {}
		}
	}
	b.fill_type = if even_odd { .even_odd } else { .winding }
	return b.detach()
}

// SkDrawTiler splits devices wider or taller than this into translated tiles.
const max_untiled_dimension = 8191

// fill_canvas_path fills path with color (an SkColor, 0xAARRGGBB) at
// global_alpha through transform ([a b c d e f]) into width x height RGBA_8888
// pixels, which are premultiplied when alpha_type is 2 and premultiplied first
// otherwise. mode is the composite operation's blend mode (canvas_blend_mode()).
// A positive blur is a shadow's blur: the paint then takes a blur mask filter
// of sigma blur / 2 instead of global_alpha (canvas_shadow_sigma()).
// Returns false without changing pixels for devices Skia would tile.
// clips are the Canvas2D clip paths in device space, applied anti-aliased in
// order (canvas_raster_clip()).
pub fn fill_canvas_path(mut pixels []u8, width int, height int, pitch int, alpha_type int, path Path, transform [6]f32, color u32, gradient ?CanvasGradient, global_alpha f32, mode BlendMode, blur_in f32, clips []Path) bool {
	if path.is_inverse_fill() || !untiled_device(pixels, width, height, pitch) {
		return false
	}
	mut target := new_canvas_target(mut pixels, width, height, pitch, alpha_type)
	paint_color, blur := canvas_paint_source(color, gradient, blur_in)
	alpha := canvas_paint_alpha(paint_color, if blur > 0 { f32(1) } else { global_alpha })
	if blend_draws_nothing(mode, paint_alpha_byte(alpha)) {
		return target.ready()
	}
	rc := canvas_raster_clip(width, height, clips)
	matrix := Matrix{transform[0], transform[1], transform[2], transform[3], transform[4], transform[5]}
	shader := canvas_paint_shader(gradient, matrix)
	if sigma := canvas_shadow_sigma(blur) {
		// SkCanvas::internalQuickReject() with the mask filter's 3 sigma
		// outset, then Draw::drawDevPath() through filterPath().
		bounds := path.bounds() or { return target.ready() }
		pad := f32(3) * sigma
		outset := Rect{bounds.left - pad, bounds.top - pad, bounds.right + pad, bounds.bottom + pad}
		if canvas_quick_reject(outset, matrix, &rc) {
			return target.ready()
		}
		device := path.transform(matrix)
		device_bounds := device.bounds() or { return target.ready() }
		if too_big_for_math(device_bounds) {
			return target.ready()
		}
		convex := device.convexity() != .concave
		plan := plan_blur(device, convex, sigma, matrix, &rc, false)
		if plan.kind == .declined {
			return false
		}
		target.ready()
		mut blitter := canvas_paint_blitter(mut pixels, pitch, paint_color, shader, alpha, mode) or {
			return true
		}
		if plan.kind == .unfiltered {
			return anti_fill_path_convex(device, convex, &rc, mut blitter)
		}
		plan.draw(&rc, blitter)
		return true
	}
	target.ready()
	mut blitter := canvas_paint_blitter(mut pixels, pitch, paint_color, shader, alpha, mode) or {
		return true
	}
	return anti_fill_path_clip(path.transform(matrix), false, &rc, mut blitter)
}

// canvas_shadow_sigma is the blur mask filter vox_skia_canvas_path() gives a
// positive shadow blur: SkMaskFilter::MakeBlur(kNormal_SkBlurStyle, blur / 2),
// which is none for a sigma that is not finite and positive.
fn canvas_shadow_sigma(blur f32) ?f32 {
	if blur > 0 {
		return new_blur_sigma(blur / 2)
	}
	return none
}

// SkCanvas::quickReject() of local bounds: mapped through the matrix and
// tested against the clip bounds outset by a pixel, empty for an empty clip.
fn canvas_quick_reject(local Rect, matrix Matrix, rc &RasterClip) bool {
	device := map_rect_affine(local, matrix)
	if !is_finite_f32(device.left) || !is_finite_f32(device.top) || !is_finite_f32(device.right)
		|| !is_finite_f32(device.bottom) {
		return true
	}
	clip_bounds := rc.bounds()
	reject_bounds := if rc.is_empty {
		Rect{}
	} else {
		Rect{f32(clip_bounds.left) - 1, f32(clip_bounds.top) - 1, f32(clip_bounds.right) + 1, f32(clip_bounds.bottom) +
			1}
	}
	reject_left := fmax_std(device.left, reject_bounds.left)
	reject_right := fmin_std(device.right, reject_bounds.right)
	reject_top := fmax_std(device.top, reject_bounds.top)
	reject_bottom := fmin_std(device.bottom, reject_bounds.bottom)
	return !(reject_left < reject_right && reject_top < reject_bottom)
}

fn untiled_device(pixels []u8, width int, height int, pitch int) bool {
	return width > 0 && height > 0 && width <= max_untiled_dimension
		&& height <= max_untiled_dimension && pitch >= width * 4 && pitch % 4 == 0
		&& i64(pitch) * i64(height - 1) + i64(width) * 4 <= i64(pixels.len)
}

// The line joins Canvas2D passes, in its encoding.
pub enum StrokeJoin {
	round
	bevel
	miter
}

// stroke_canvas_path strokes path the way vox_skia_canvas_path() does for a
// solid stroke without filters or shadows. When line_width
// mapped through transform is at most one device pixel along both axes,
// SkDraw draws a one-pixel hairline with alpha scaled by the width; wider
// strokes are outlined by SkStroke in source space and the outline is filled
// in device space. dashes and dash_offset are the SkDashPathEffect intervals
// and phase, which cut the path into dashes first; Skia ignores an empty or
// invalid list. clips are the device-space clip paths, as for
// fill_canvas_path(). color is the style's SkColor before global_alpha, and
// mode the composite operation's blend mode: a thin stroke stays an outline
// unless the mode supports coverage as alpha or the stroke is a full pixel.
// blur is a shadow's blur, as for fill_canvas_path(); the blur mask filter
// draws hairlines into its mask with butt caps.
// Returns false without changing pixels for devices Skia would tile.
pub fn stroke_canvas_path(mut pixels []u8, width int, height int, pitch int, alpha_type int, path Path, transform [6]f32, color u32, gradient ?CanvasGradient, global_alpha f32, mode BlendMode, blur_in f32, line_width f32, cap StrokeCap, join StrokeJoin, miter f32, dashes []f32, dash_offset f32, clips []Path) bool {
	if !untiled_device(pixels, width, height, pitch) {
		return false
	}
	for v in transform {
		if !is_finite_f32(v) {
			return false
		}
	}
	matrix := Matrix{transform[0], transform[1], transform[2], transform[3], transform[4], transform[5]}
	// SkPaint::setStrokeWidth() and setStrokeMiter() ignore negative and NaN
	// values; the defaults are 0 (a hairline) and 4.
	stroke_width := if line_width >= 0 { line_width } else { f32(0) }
	miter_limit := if miter >= 0 { miter } else { f32(4) }
	// DrawTreatAsHairline(): the stroke width's device vectors. Then
	// modifyPaintForHairlines() draws a hairline at full coverage, or with
	// the coverage in its alpha when the blend mode supports that.
	mut coverage := f32(1)
	mut hairline := true
	if stroke_width != 0 {
		len0 := fast_len(stroke_width * matrix.a, stroke_width * matrix.b)
		len1 := fast_len(stroke_width * matrix.c, stroke_width * matrix.d)
		if len0 <= 1 && len1 <= 1 {
			coverage = float_midpoint(len0, len1)
			hairline = coverage == 1 || blend_prescales_coverage(mode)
		} else {
			hairline = false
		}
	}
	mut target := new_canvas_target(mut pixels, width, height, pitch, alpha_type)
	// vox_skia_canvas_path() draws nothing for non-positive widths.
	if line_width <= 0 {
		return target.ready()
	}
	paint_color, blur := canvas_paint_source(color, gradient, blur_in)
	paint_alpha := canvas_paint_alpha(paint_color, if blur > 0 { f32(1) } else { global_alpha })
	shader := canvas_paint_shader(gradient, matrix)
	alpha := paint_alpha_byte(paint_alpha)
	sigma := canvas_shadow_sigma(blur)
	// SkCanvas::onDrawPath(): non-finite paths, SkPaint::nothingToDraw() and
	// internalQuickReject().
	bounds := path.bounds() or { return target.ready() }
	if blend_draws_nothing(mode, alpha) || path.is_inverse_fill() {
		return target.ready()
	}
	// SkPaint::computeFastBounds(): the stroke's inflation, then the blur
	// mask filter's 3 sigma.
	radius := inflation_radius(stroke_width, cap, join, miter_limit)
	mut outset := Rect{bounds.left - radius, bounds.top - radius, bounds.right + radius, bounds.bottom +
		radius}
	if s := sigma {
		pad := f32(3) * s
		outset = Rect{outset.left - pad, outset.top - pad, outset.right + pad, outset.bottom + pad}
	}
	rc := canvas_raster_clip(width, height, clips)
	clip_bounds := rc.bounds()
	if canvas_quick_reject(outset, matrix, &rc) {
		return target.ready()
	}
	// skpathutils::FillPathWithPaint(): the dash path effect first, with the
	// device clip mapped into source space as its cull rect, at the matrix's
	// resolution scale. A hairline's stroke record has width 0.
	res_scale := res_scale_for_stroking(matrix)
	mut source := path
	mut fill_dashes := false
	mut dashed := false
	if dash := new_dash_effect(dashes, dash_offset) {
		stroke := DashStroke{
			width:       if hairline { f32(0) } else { stroke_width }
			cap:         cap
			join:        join
			miter_limit: miter_limit
			res_scale:   res_scale
		}
		result := dash_path(path, dash, stroke, local_clip_bounds(matrix, clip_bounds))
		fill_dashes = result.fill
		if result.applied {
			source = result.path
			dashed = true
		}
	}
	if !hairline {
		// SkStrokeRec::applyToPath(), unless the dashes are already outlines,
		// an empty path when the result is not finite, then
		// SkPathBuilder::transform() and SkScan::AntiFillPath().
		mut outline := if fill_dashes {
			StrokeOutline{
				builder: PathBuilder{
					verbs:   source.verbs
					points:  source.points
					weights: source.weights
				}
			}
		} else {
			stroke_path(source, stroke_width, cap, join, miter_limit, res_scale)
		}
		for p in outline.builder.points {
			if !point_is_finite(p) {
				outline = StrokeOutline{}
				break
			}
		}
		device_path, known_convex := outline.transformed(matrix)
		if s := sigma {
			device_bounds := device_path.bounds() or { return target.ready() }
			if too_big_for_math(device_bounds) {
				return target.ready()
			}
			convex := known_convex || device_path.convexity() != .concave
			plan := plan_blur(device_path, convex, s, matrix, &rc, false)
			if plan.kind == .declined {
				return false
			}
			target.ready()
			mut blitter := canvas_paint_blitter(mut pixels, pitch, paint_color, shader, paint_alpha,
				mode) or { return true }
			if plan.kind == .unfiltered {
				anti_fill_path_convex(device_path, convex, &rc, mut blitter)
			} else {
				plan.draw(&rc, blitter)
			}
			return true
		}
		target.ready()
		mut blitter := canvas_paint_blitter(mut pixels, pitch, paint_color, shader, paint_alpha,
			mode) or { return true }
		anti_fill_path_clip(device_path, known_convex, &rc, mut blitter)
		return true
	}
	if dashed {
		for p in source.points {
			if !point_is_finite(p) {
				return target.ready()
			}
		}
	}
	// modifyPaintForHairlines(): partial coverage scales the paint's alpha.
	mut hair_alpha := paint_alpha
	if coverage != 1 {
		scale := int(saturate_to_i32(coverage * f32(256)))
		hair_alpha = tpin(f32((alpha * scale) >> 8) * inv_255, 0, 1)
	}
	device_path := source.transform(matrix)
	if s := sigma {
		device_bounds := device_path.bounds() or { return target.ready() }
		if too_big_for_math(device_bounds) {
			return target.ready()
		}
		plan := plan_blur(device_path, false, s, matrix, &rc, true)
		target.ready()
		mut blitter := canvas_paint_blitter(mut pixels, pitch, paint_color, shader, hair_alpha, mode) or {
			return true
		}
		if plan.kind == .unfiltered {
			anti_hair_path_clip(device_path, cap, &rc, mut blitter)
		} else {
			plan.draw(&rc, blitter)
		}
		return true
	}
	target.ready()
	mut blitter := canvas_paint_blitter(mut pixels, pitch, paint_color, shader, hair_alpha, mode) or {
		return true
	}
	anti_hair_path_clip(device_path, cap, &rc, mut blitter)
	return true
}

// The canvas pixels, which writePixels() premultiplies. A draw premultiplies
// them once it draws or is known to draw nothing; until then it can still
// decline without changing them.
struct CanvasTarget {
	width  int
	height int
	pitch  int
mut:
	pixels  []u8
	pending bool
}

fn new_canvas_target(mut pixels []u8, width int, height int, pitch int, alpha_type int) CanvasTarget {
	return CanvasTarget{
		width:   width
		height:  height
		pitch:   pitch
		pixels:  pixels
		pending: alpha_type != 2
	}
}

// ready premultiplies the pixels unless they already are, and returns true.
fn (mut t CanvasTarget) ready() bool {
	if t.pending {
		premultiply_rows(mut t.pixels, t.width, t.height, t.pitch)
		t.pending = false
	}
	return true
}

// fast_len(): max + min / 2.
fn fast_len(x f32, y f32) f32 {
	mut ax := f32(math.abs(x))
	mut ay := f32(math.abs(y))
	if ax < ay {
		ax, ay = ay, ax
	}
	half := ay * f32(0.5)
	return ax + half
}

// SkStrokeRec::GetInflationRadius().
fn inflation_radius(width f32, cap StrokeCap, join StrokeJoin, miter_limit f32) f32 {
	if width == 0 {
		return 1
	}
	mut multiplier := f32(1)
	if join == .miter && multiplier < miter_limit {
		multiplier = miter_limit
	}
	sqrt2 := f32(1.41421356)
	if cap == .square && multiplier < sqrt2 {
		multiplier = sqrt2
	}
	half := width / 2
	return half * multiplier
}

// SkMatrixPriv::MapRect() for an affine SkM44: the bounds of the mapped
// corners, translated last.
fn map_rect_affine(r Rect, m Matrix) Rect {
	mut mins := [4]f32{}
	for i, corner in [Point{r.left, r.top}, Point{r.right, r.top}, Point{r.left, r.bottom},
		Point{r.right, r.bottom}] {
		ax := m.a * corner.x
		cy := m.c * corner.y
		bx := m.b * corner.x
		dy := m.d * corner.y
		nax := -m.a * corner.x
		ncy := -m.c * corner.y
		nbx := -m.b * corner.x
		ndy := -m.d * corner.y
		lanes := [ax + cy, bx + dy, nax + ncy, nbx + ndy]!
		for k in 0 .. 4 {
			mins[k] = if i == 0 { lanes[k] } else { fmin(mins[k], lanes[k]) }
		}
	}
	return Rect{m.e + mins[0], m.f + mins[1], m.e - mins[2], m.f - mins[3]}
}

// SkPaint::getAlpha(): sk_float_round2int(alpha * 255).
fn paint_alpha_byte(alpha f32) int {
	scaled := alpha * f32(255)
	return int(math.floor(f64(scaled) + 0.5))
}

// SkColor4f::toSkColor() for one channel: trunc(pin(v * 255 + 0.5, 0, 255)).
fn color4f_byte(v f32) u32 {
	scaled := v * f32(255)
	biased := scaled + f32(0.5)
	return u32(u8(fmin(fmax(biased, 0), 255)))
}

// apply_style() for the paint's source: a gradient leaves SkPaint's default
// opaque black color, and only a solid color's shadow takes the blur mask
// filter. Returns the paint color and the blur that applies.
fn canvas_paint_source(color u32, gradient ?CanvasGradient, blur f32) (u32, f32) {
	if _ := gradient {
		return u32(0xff000000), f32(0)
	}
	return color, blur
}

fn canvas_paint_shader(gradient ?CanvasGradient, m Matrix) ?CanvasShader {
	g := gradient or { return none }
	return canvas_gradient_shader(g, m)
}

// The paint's SkColor4f alpha after SkPaint::setAlphaf(getAlphaf() * global_alpha).
fn canvas_paint_alpha(color u32, global_alpha f32) f32 {
	v := f32(color >> 24) * inv_255
	product := v * global_alpha
	pinned := if product < 1 { product } else { f32(1) }
	return if f32(0) < pinned { pinned } else { f32(0) }
}

// SkConvertPixels' RGBA_to_rgbA(): (c * a + 127) / 255.
fn premultiply_rows(mut pixels []u8, width int, height int, pitch int) {
	for y in 0 .. height {
		row := y * pitch
		for x in 0 .. width {
			o := row + x * 4
			a := u32(pixels[o + 3])
			for c in 0 .. 3 {
				pixels[o + c] = u8((u32(pixels[o + c]) * a + 127) / 255)
			}
		}
	}
}
