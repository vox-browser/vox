module cpuraster

// Canvas2D filters made only of color matrices: make_filter() wraps each in
// SkImageFilters::ColorFilter(), which composes consecutive color filters
// into one node. With no input and no effect on transparent black,
// SkCanvasPriv::ImageToColorFilter() moves that node into the paint's color
// filter slot instead of drawing through a layer, and SkBlitter::Choose()
// then folds it into the paint (SkPaintPriv::RemoveColorFilter()): a solid
// color is filtered once, and a shader becomes an SkColorFilterShader that
// runs the filter's stages after its own.

// MatrixColorFilter is SkColorFilters::Matrix(): a row-major 4x5 matrix on
// unpremultiplied RGBA, translations in [0, 1] units, then either every
// channel or only alpha clamped to [0, 1].
pub struct MatrixColorFilter {
pub:
	matrix [20]f32
	clamp  bool
}

// ColorFilter is the composition of matrix filters in drawing order: the
// first filter applies first.
pub struct ColorFilter {
pub:
	filters []MatrixColorFilter
}

// new_color_filter composes the matrices, dropping non-finite ones as
// SkColorFilters::Matrix() does. None when nothing remains.
pub fn new_color_filter(filters []MatrixColorFilter) ?ColorFilter {
	mut kept := []MatrixColorFilter{}
	for f in filters {
		if f.matrix[..].all(is_finite_f32(it)) {
			kept << f
		}
	}
	if kept.len == 0 {
		return none
	}
	return ColorFilter{kept}
}

// is_alpha_unchanged(): the alpha row is (0, 0, 0, 1, 0) within
// SK_ScalarNearlyZero.
fn (f MatrixColorFilter) alpha_unchanged() bool {
	tolerance := f32(1) / f32(1 << 12)
	m := f.matrix
	return nearly_zero(m[15], tolerance) && nearly_zero(m[16], tolerance)
		&& nearly_zero(m[17], tolerance) && nearly_equal(m[18], 1, tolerance)
		&& nearly_zero(m[19], tolerance)
}

// SkComposeColorFilter::isAlphaUnchanged().
fn (f &ColorFilter) alpha_unchanged() bool {
	return f.filters.all(it.alpha_unchanged())
}

// The filters' highp stages on a premultiplied color: per matrix, unpremul
// unless the input is known opaque, matrix_4x5's nested fused
// multiply-adds, clamp_01 or clamp_a_01, and premul unless the output
// stays opaque. A filter's input is opaque when the color was and every
// earlier filter kept alpha (SkComposeColorFilter::appendStages()).
fn (f &ColorFilter) apply(c [4]f32, opaque bool) [4]f32 {
	mut r := c[0]
	mut g := c[1]
	mut b := c[2]
	mut a := c[3]
	mut input_opaque := opaque
	for filter in f.filters {
		stays_opaque := input_opaque && filter.alpha_unchanged()
		if !input_opaque {
			inverse := f32(1) / a
			scale := if inverse < f32_infinity { inverse } else { f32(0) }
			r = r * scale
			g = g * scale
			b = b * scale
		}
		m := filter.matrix
		nr := mad(r, m[0], mad(g, m[1], mad(b, m[2], mad(a, m[3], m[4]))))
		ng := mad(r, m[5], mad(g, m[6], mad(b, m[7], mad(a, m[8], m[9]))))
		nb := mad(r, m[10], mad(g, m[11], mad(b, m[12], mad(a, m[13], m[14]))))
		na := mad(r, m[15], mad(g, m[16], mad(b, m[17], mad(a, m[18], m[19]))))
		r, g, b, a = nr, ng, nb, na
		if filter.clamp {
			r = neon_min(neon_max(0, r), 1)
			g = neon_min(neon_max(0, g), 1)
			b = neon_min(neon_max(0, b), 1)
		}
		a = neon_min(neon_max(0, a), 1)
		if !stays_opaque {
			r = r * a
			g = g * a
			b = b * a
		}
		input_opaque = input_opaque && filter.alpha_unchanged()
	}
	return [r, g, b, a]!
}

// SkColorFilter::filterColor4f() from and to sRGB: the unpremultiplied
// color premultiplied, onFilterColor4f()'s one-pixel pipeline (opaque when
// alpha is 1), alpha pinned, then unpremultiplied.
fn (f &ColorFilter) filter_color4f(c [4]f32) [4]f32 {
	premul := [c[0] * c[3], c[1] * c[3], c[2] * c[3], c[3]]!
	out := f.apply(premul, c[3] == 1)
	a := if out[3] < 0 {
		f32(0)
	} else if out[3] > 1 {
		f32(1)
	} else {
		out[3]
	}
	if a == 0 {
		return [f32(0), 0, 0, 0]!
	}
	inverse := f32(1) / a
	return [out[0] * inverse, out[1] * inverse, out[2] * inverse, a]!
}

// SkColorFilterBase::affectsTransparentBlack(): such a filter is not moved
// into the paint, and draws through an image filter layer instead.
fn (f &ColorFilter) affects_transparent_black() bool {
	out := f.filter_color4f([f32(0), 0, 0, 0]!)
	return out[0] != 0 || out[1] != 0 || out[2] != 0 || out[3] != 0
}

// The paint after RemoveColorFilter() for a solid color: its
// unpremultiplied SkColor4f from the SkColor's channels and the paint
// alpha, filtered, with alpha pinned by SkPaint::setColor().
fn filtered_paint_color(color u32, alpha f32, filter ColorFilter) [4]f32 {
	c := [f32((color >> 16) & 0xff) * inv_255, f32((color >> 8) & 0xff) * inv_255,
		f32(color & 0xff) * inv_255, alpha]!
	return filter.filter_color4f(c)
}

// SkPaint::nothingToDraw() at the quick reject, while the filter is still
// the paint's image filter: an image filter may affect alpha, so only Dst
// draws nothing.
fn paint_draws_nothing(mode BlendMode, alpha_byte int, filter ?ColorFilter) bool {
	if _ := filter {
		return mode == .dst
	}
	return blend_draws_nothing(mode, alpha_byte)
}

// SkBlitter::Choose() for the canvas paint with or without a color filter.
fn canvas_draw_blitter_for_surface(mut pixels []u8, row_bytes int, color u32, shader ?CanvasShader, alpha f32, mode BlendMode, device_bounds Rect, filter ?ColorFilter, legacy bool) ?Blitter {
	f := filter or {
		return canvas_paint_blitter_for_surface(mut pixels, row_bytes, color, shader, alpha, mode, device_bounds, legacy)
	}
	return canvas_filtered_blitter(mut pixels, row_bytes, color, shader, alpha, mode, device_bounds,
		f, legacy)
}

// SkBlitter::Choose() with a color filter. CheckFastPath() sees the
// filter, so only Dst draws nothing and no mode becomes source-over; Clear
// drops the shader and filter. RemoveColorFilter() then filters a solid
// color, or wraps a shader in SkColorFilterShader: the shader, the paint
// alpha's scale_1_float and the filter's stages, all in highp, with no
// legacy shader context.
fn canvas_filtered_blitter(mut pixels []u8, row_bytes int, color u32, shader ?CanvasShader, alpha f32, mode BlendMode, device_bounds Rect, filter ColorFilter, legacy bool) ?Blitter {
	if mode == .dst {
		return none
	}
	if mode == .clear {
		return canvas_blitter(mut pixels, row_bytes, 0, 0, .clear)
	}
	s := shader or { return filtered_color_blitter(mut pixels, row_bytes, color, alpha, mode, filter, legacy) }
	opaque_after := filter.alpha_unchanged()
	match s.kind {
		.null_ {
			return filtered_color_blitter(mut pixels, row_bytes, 0xff000000, alpha, mode, filter, legacy)
		}
		.empty {
			return none
		}
		.color {
			// SkColorShader's premultiplied uniform color, no longer constant.
			c := s.color
			shader_opaque := c[3] == 1
			blend := if mode == .src_over && shader_opaque && alpha == 1 && opaque_after {
				BlendMode.src
			} else {
				mode
			}
			return PipelineBlitter{
				mode:          blend
				prescale:      blend_prescales_coverage(blend)
				row_bytes:     row_bytes
				fr:            c[0] * c[3]
				fg:            c[1] * c[3]
				fb:            c[2] * c[3]
				fa:            c[3]
				scaled:        alpha != 1
				scale:         alpha
				filtered:      true
				filter:        filter
				filter_opaque: shader_opaque && alpha == 1
				pixels:        pixels
			}
		}
		.gradient {
			base := new_gradient_blitter(mut pixels, row_bytes, s.gradient, alpha, mode)
			shader_opaque := s.gradient.opaque && alpha == 1
			blend := if mode == .src_over && shader_opaque && opaque_after { BlendMode.src } else { mode }
			return PipelineBlitter{
				...base
				mode:          blend
				lowp:          false
				prescale:      blend_prescales_coverage(blend)
				filtered:      true
				filter:        filter
				filter_opaque: shader_opaque
			}
		}
		.image {
			mut image := s.image
			image.check_device_bounds(device_bounds)
			base := new_image_blitter(mut pixels, row_bytes, image, alpha, mode)
			return PipelineBlitter{
				...base
				lowp:     false
				filtered: true
				filter:   filter
			}
		}
	}
}

// A solid paint after RemoveColorFilter(): the legacy blitter for
// source-over when the filtered color fits in bytes (rounded to an
// SkColor), otherwise the raster pipeline's constant color.
fn filtered_color_blitter(mut pixels []u8, row_bytes int, color u32, alpha f32, mode BlendMode, filter ColorFilter, legacy bool) Blitter {
	c := filtered_paint_color(color, alpha, filter)
	if legacy && mode == .src_over && c[..3].all(it >= 0 && it <= 1) {
		sk := color4f_byte(c[3]) << 24 | color4f_byte(c[0]) << 16 | color4f_byte(c[1]) << 8 | color4f_byte(c[2])
		return new_solid_blitter(mut pixels, row_bytes, sk)
	}
	return new_constant_blitter(mut pixels, row_bytes, [c[0] * c[3], c[1] * c[3], c[2] * c[3], c[3]]!,
		1, mode)
}
