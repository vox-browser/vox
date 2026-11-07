module cpuraster

import math

// SkImageShader (google/skia ee20d565) for Canvas2D patterns as
// skia/canvas_raster.cpp's apply_style() makes them: an RGBA_8888 image in
// sRGB or Display P3, unpremultiplied or premultiplied, repeated or decal on
// each axis (kDecal for the axes CanvasPattern's repetition does not
// repeat), sampled with SkFilterMode::kLinear through the canvas transform
// and the pattern's own transform. appendStages() selects nearest sampling
// for integer translations, the tiling stages, gather_8888 or the bilinear
// sampler (bilinear_setup, four bilinear_[np]x/[np]y samples and
// accumulate), the clamp-clamp bilerp_clamp_8888 fast path, then the
// SkColorSpaceXformSteps to premultiplied sRGB. Lowp exists only for the
// decal and clamp nearest stages, bilerp_clamp_8888 and premul.

// A Canvas2D pattern in skia.Style's kind 4 encoding: RGBA_8888 pixels.
pub struct CanvasPattern {
pub:
	pixels        []u8
	width         int
	height        int
	pitch         int
	premultiplied bool
	// Display P3 instead of sRGB.
	display_p3 bool
	// CanvasPattern's repetition: 0 repeat, 1 repeat-x, 2 repeat-y and
	// 3 no-repeat.
	repetition int
	// The pattern transform, [a b c d e f].
	transform [6]f32
}

// The paint's non-solid source.
pub type CanvasPaintStyle = CanvasGradient | CanvasPattern

enum TileMode {
	clamp
	repeat
	decal
}

struct ImageShader {
	pixels []u8
	width  int
	height int
	// GatherCtx::stride: row bytes in pixels.
	stride int
	// The inverse of the canvas transform concatenated with the pattern's.
	matrix  SkAffine
	nearest bool
	tile_x  TileMode
	tile_y  TileMode
	// SkColorSpaceXformSteps' unpremul, Display P3 to sRGB (linearize,
	// gamut transform and encode) and premul stages.
	unpremul   bool
	display_p3 bool
	premul     bool
mut:
	// bilerp_clamp_8888_force_highp: device bounds that map outside the
	// 16-bit range in image space.
	force_highp bool
}

// optimize(): repeating a one-pixel axis is clamping it.
fn optimize_tile(mode TileMode, dimension int) TileMode {
	return if mode != .decal && dimension == 1 { TileMode.clamp } else { mode }
}

// canvas_pattern_shader is apply_style()'s SkImage::makeShader() for pattern
// under the canvas matrix m.
fn canvas_pattern_shader(pattern CanvasPattern, m Matrix) CanvasShader {
	repeat_x := pattern.repetition == 0 || pattern.repetition == 1
	repeat_y := pattern.repetition == 0 || pattern.repetition == 2
	t := pattern.transform
	local := SkAffine{
		sx: t[0]
		kx: t[2]
		tx: t[4]
		ky: t[1]
		sy: t[3]
		ty: t[5]
	}
	ctm := SkAffine{
		sx: m.a
		kx: m.c
		tx: m.e
		ky: m.b
		sy: m.d
		ty: m.f
	}
	// MatrixRec::totalInverse(): the CTM concatenated with the local matrix.
	inverse := affine_invert(sk_concat(ctm, local)) or {
		return CanvasShader{
			kind: .empty
		}
	}
	// tweak_sampling(): bilinear sampling of an integer translation is
	// nearest-neighbor sampling.
	nearest := inverse.type_mask() <= affine_translate_mask && int_cast_preserves(inverse.tx)
		&& int_cast_preserves(inverse.ty)
	opaque_source := false
	return CanvasShader{
		kind:  .image
		image: ImageShader{
			pixels:     pattern.pixels
			width:      pattern.width
			height:     pattern.height
			stride:     pattern.pitch / 4
			matrix:     inverse
			nearest:    nearest
			tile_x:     optimize_tile(if repeat_x { TileMode.repeat } else { .decal }, pattern.width)
			tile_y:     optimize_tile(if repeat_y { TileMode.repeat } else { .decal }, pattern.height)
			unpremul:   pattern.display_p3 && pattern.premultiplied
			display_p3: pattern.display_p3
			premul:     !opaque_source && (pattern.display_p3 || !pattern.premultiplied)
		}
	}
}

// v == (int)v as arm64 computes it: fcvtzs saturates at the int range.
fn int_cast_preserves(v f32) bool {
	if v != v {
		return false
	}
	if f64(v) >= 2147483647.0 {
		return f64(v) == 2147483648.0
	}
	if f64(v) <= -2147483648.0 {
		return f64(v) == -2147483648.0
	}
	return f32(math.trunc(f64(v))) == v
}

// The bilerp_clamp_8888 fast path: linear sampling with both axes clamped.
fn (s &ImageShader) fast_bilerp() bool {
	return !s.nearest && s.tile_x == .clamp && s.tile_y == .clamp
}

// Whether a stage lacks a lowp version: the bilinear sampler, the repeat
// tiles, the color space transform and bilerp_clamp_8888_force_highp.
fn (s &ImageShader) needs_highp() bool {
	if s.display_p3 {
		return true
	}
	if s.fast_bilerp() {
		return s.force_highp
	}
	return !s.nearest || s.tile_x == .repeat || s.tile_y == .repeat
}

// The fast path's shouldUseHighPBilerp: the device bounds of the draw
// mapped into image space leave the 16-bit range or are not finite.
fn (mut s ImageShader) check_device_bounds(bounds Rect) {
	if !s.fast_bilerp() || !(bounds.left < bounds.right && bounds.top < bounds.bottom) {
		return
	}
	quad := [Point{bounds.left, bounds.top}, Point{bounds.right, bounds.top},
		Point{bounds.right, bounds.bottom}, Point{bounds.left, bounds.bottom}]
	mut mapped := []Point{cap: 4}
	for p in quad {
		mapped << s.matrix.map(p)
	}
	image := bounds_no_check(mapped)
	for v in [image.left, image.top, image.right, image.bottom] {
		if v > 32767 || v < -32768 || !is_finite_f32(v) {
			s.force_highp = true
			return
		}
	}
}

// Highp.

// exclusive_repeat(): v - floor(v / scale) * scale with Skia's reciprocal.
fn exclusive_repeat(v f32, limit int) f32 {
	scale := f32(limit)
	inv_scale := f32(1) / scale
	scaled := v * inv_scale
	tiles := floor_f32(scaled)
	offset := tiles * scale
	return v - offset
}

// decal_x/decal_y: inside (0, limit) or on the inclusive edge, which
// nearest sampling moves from 0 to the limit.
fn (s &ImageShader) highp_decal(v f32, limit int) bool {
	l := f32(limit)
	edge := if s.nearest { l } else { f32(0) }
	return (0 < v && v < l) || v == edge
}

// ix_and_ptr()'s exclusive clamp and roundDownAtInteger, then trunc_().
fn (s &ImageShader) highp_index(x f32, y f32) int {
	lx := math.f32_from_bits(math.f32_bits(f32(s.width)) - 1)
	ly := math.f32_from_bits(math.f32_bits(f32(s.height)) - 1)
	mut cx := neon_min(neon_max(f32_min_normal, x), lx)
	mut cy := neon_min(neon_max(f32_min_normal, y), ly)
	if s.nearest {
		cx = math.f32_from_bits(math.f32_bits(cx) - 1)
		cy = math.f32_from_bits(math.f32_bits(cy) - 1)
	}
	return int(neon_trunc(cy)) * s.stride + int(neon_trunc(cx))
}

// fcvtzs: truncation with NaN as 0 and saturation.
fn neon_trunc(v f32) i32 {
	if v != v {
		return 0
	}
	if f64(v) >= 2147483647.0 {
		return max_i32
	}
	if f64(v) <= -2147483648.0 {
		return min_i32
	}
	return i32(math.trunc(f64(v)))
}

// gather_8888's from_8888(): bytes times 1/255.
fn (s &ImageShader) highp_pixel(index int) [4]f32 {
	o := index * 4
	return [f32(s.pixels[o]) * inv_255, f32(s.pixels[o + 1]) * inv_255, f32(s.pixels[o + 2]) * inv_255,
		f32(s.pixels[o + 3]) * inv_255]!
}

// The tiling stages, gather_8888 and check_decal_mask at (x, y).
fn (s &ImageShader) highp_sample(x_in f32, y_in f32) [4]f32 {
	mut x := x_in
	mut y := y_in
	mut keep := true
	if s.tile_x == .decal && s.tile_y == .decal {
		keep = s.highp_decal(x, s.width) && s.highp_decal(y, s.height)
	} else {
		match s.tile_x {
			.repeat { x = exclusive_repeat(x, s.width) }
			.decal { keep = s.highp_decal(x, s.width) }
			.clamp {}
		}
		match s.tile_y {
			.repeat { y = exclusive_repeat(y, s.height) }
			.decal { keep = s.highp_decal(y, s.height) }
			.clamp {}
		}
	}
	c := s.highp_pixel(s.highp_index(x, y))
	if !keep {
		return [f32(0), 0, 0, 0]!
	}
	return c
}

@[inline]
fn fract_f32(v f32) f32 {
	return v - floor_f32(v)
}

// shade_highp: the premultiplied sRGB color at pixel (px, py).
fn (s &ImageShader) shade_highp(px int, py int) [4]f32 {
	sx := f32(px) + f32(0.5)
	sy := f32(py) + f32(0.5)
	x, y := apply_matrix(s.matrix, sx, sy, true)
	mut c := [f32(0), 0, 0, 0]!
	if s.nearest {
		c = s.highp_sample(x, y)
	} else if s.fast_bilerp() {
		// bilerp_clamp_large(): four clamped samples weighted by area.
		fx := fract_f32(x + f32(0.5))
		fy := fract_f32(y + f32(0.5))
		for oy in [f32(-0.5), 0.5] {
			for ox in [f32(-0.5), 0.5] {
				sample := s.highp_pixel(s.highp_index(x + ox, y + oy))
				wx := if ox > 0 { fx } else { f32(1) - fx }
				wy := if oy > 0 { fy } else { f32(1) - fy }
				area := wx * wy
				for i in 0 .. 4 {
					weighted := sample[i] * area
					c[i] = c[i] + weighted
				}
			}
		}
	} else {
		// bilinear_setup, then the four samples' accumulate.
		fx := fract_f32(x + f32(0.5))
		fy := fract_f32(y + f32(0.5))
		for oy in [f32(-0.5), 0.5] {
			for ox in [f32(-0.5), 0.5] {
				wx := if ox > 0 { fx } else { f32(1) - fx }
				wy := if oy > 0 { fy } else { f32(1) - fy }
				sample := s.highp_sample(x + ox, y + oy)
				scale := wx * wy
				for i in 0 .. 4 {
					c[i] = mad(scale, sample[i], c[i])
				}
			}
		}
	}
	mut pixel := FloatPixel{c[0], c[1], c[2], c[3]}
	if s.unpremul {
		pixel.unpremul()
	}
	if s.display_p3 {
		pixel.transfer(srgb_to_linear)
		pixel.matrix_3x3(display_p3_to_srgb)
		pixel.transfer(linear_to_srgb)
	}
	if s.premul {
		pixel.premul()
	}
	return [pixel.r, pixel.g, pixel.b, pixel.a]!
}

// Lowp.

// lowp ix_and_ptr(): the inclusive limits and x < y min and max.
fn (s &ImageShader) lowp_index(x f32, y f32) int {
	lx := math.f32_from_bits(math.f32_bits(f32(s.width)) - 1)
	ly := math.f32_from_bits(math.f32_bits(f32(s.height)) - 1)
	mut cx := lowp_fmin(lowp_fmax(f32_min_normal, x), lx)
	mut cy := lowp_fmin(lowp_fmax(f32_min_normal, y), ly)
	if s.nearest {
		cx = math.f32_from_bits(math.f32_bits(cx) - 1)
		cy = math.f32_from_bits(math.f32_bits(cy) - 1)
	}
	return int(neon_trunc(cy)) * s.stride + int(neon_trunc(cx))
}

// shade_lowp: the premultiplied color in 16-bit lanes at pixel (px, py).
fn (s &ImageShader) shade_lowp(px int, py int) [4]u32 {
	sx := f32(px) + f32(0.5)
	sy := f32(py) + f32(0.5)
	x, y := apply_matrix(s.matrix, sx, sy, false)
	mut c := [u32(0), 0, 0, 0]!
	if s.fast_bilerp() {
		// bilerp_clamp_8888 of the one-pixel image the clamped axes come
		// from: its fixed-point lerps of equal pixels return the pixel.
		for i in 0 .. 4 {
			c[i] = u32(s.pixels[i])
		}
	} else {
		// decal_x, decal_y or decal_x_and_y: [0, limit) on each axis.
		wx := f32(s.width)
		hy := f32(s.height)
		keep_x := s.tile_x != .decal || (0 <= x && x < wx)
		keep_y := s.tile_y != .decal || (0 <= y && y < hy)
		o := s.lowp_index(x, y) * 4
		if keep_x && keep_y {
			for i in 0 .. 4 {
				c[i] = u32(s.pixels[o + i])
			}
		}
	}
	if s.premul {
		for i in 0 .. 3 {
			c[i] = div255_accurate(c[i] * c[3])
		}
	}
	return c
}
