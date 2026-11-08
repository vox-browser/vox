module cpuraster

import math

// SkImageShader (google/skia ee20d565) for Canvas2D patterns and images:
// an RGBA_8888 image in sRGB or Display P3, unpremultiplied or
// premultiplied. Patterns are repeated or decal on each axis (kDecal for the
// axes CanvasPattern's repetition does not repeat) and sampled with
// SkFilterMode::kLinear through the canvas transform and the pattern's own
// transform, as skia/canvas_raster.cpp's apply_style() makes them;
// drawImage() clamps, with nearest or linear sampling. appendStages()
// selects nearest sampling for integer translations, the tiling stages,
// gather_8888 or the bilinear sampler (bilinear_setup, four
// bilinear_[np]x/[np]y samples and accumulate), the clamp-clamp
// bilerp_clamp_8888 fast path, then the SkColorSpaceXformSteps to
// premultiplied sRGB. Lowp exists only for the decal and clamp nearest
// stages, bilerp_clamp_8888 and premul.

// RGBA_8888 image pixels, as skia.Style's kind 4 fields describe them.
pub struct CanvasBitmap {
	// Native services and filter layers use N32; public canvas images are RGBA.
	native_n32 bool = true
pub:
	pixels        []u8
	width         int
	height        int
	pitch         int
	premultiplied bool
	// Display P3 instead of sRGB.
	display_p3 bool
}

// SkBitmap::installPixels() accepts a non-empty image with rows at least
// as long as its width.
fn (b &CanvasBitmap) installs() bool {
	return b.width > 0 && b.height > 0 && b.pitch >= b.width * 4
		&& b.pixels.len >= b.pitch * (b.height - 1) + b.width * 4
}

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

fn (p &CanvasPattern) bitmap() CanvasBitmap {
	return CanvasBitmap{
		pixels:        p.pixels
		width:         p.width
		height:        p.height
		pitch:         p.pitch
		premultiplied: p.premultiplied
		display_p3:    p.display_p3
		native_n32:    canvas_rgba_uses_legacy()
	}
}

// The paint's non-solid source.
pub type CanvasPaintStyle = CanvasGradient | CanvasPattern

enum TileMode {
	clamp
	repeat
	decal
}

struct ImageShader {
	native_n32 bool
	pixels []u8
	width  int
	height int
	// GatherCtx::stride: row bytes in pixels.
	stride int
	// The inverse of the canvas transform concatenated with the local matrix.
	matrix SkAffine
	// The requested SkFilterMode::kLinear, and the nearest sampling the
	// raster pipeline uses (tweak_sampling()).
	linear  bool
	nearest bool
	tile_x  TileMode
	tile_y  TileMode
	// SkColorSpaceXformSteps' unpremul, Display P3 to sRGB (linearize,
	// gamut transform and encode) and premul stages.
	unpremul   bool
	display_p3 bool
	premul     bool
	// Linear mipmaps sample two levels before color-space conversion. Even
	// a single level uses the general bilinear stages for this sampling mode.
	mipmap_linear bool
	lower &ImageShader = unsafe { nil }
	lower_weight f32
	lower_scale_x f32
	lower_scale_y f32
	// sk_decal applies its one-pixel edge ramp in layer coordinates, after
	// sampling the clamped source, before the deferred color filter.
	layer_decal bool
	decal_bounds Rect
mut:
	// bilerp_clamp_8888_force_highp: device bounds that map outside the
	// 16-bit range in image space.
	force_highp bool
}

// optimize(): repeating a one-pixel axis is clamping it.
fn optimize_tile(mode TileMode, dimension int) TileMode {
	return if mode != .decal && dimension == 1 { TileMode.clamp } else { mode }
}

fn matrix_affine(m Matrix) SkAffine {
	return SkAffine{
		sx: m.a
		kx: m.c
		tx: m.e
		ky: m.b
		sy: m.d
		ty: m.f
	}
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
	return new_image_shader(pattern.bitmap(), if repeat_x { TileMode.repeat } else { .decal },
		if repeat_y { TileMode.repeat } else { .decal }, true, sk_concat(matrix_affine(m), local))
}

// new_image_shader is SkImageShader::Make() for bitmap with its tile modes
// and requested sampling, under the total matrix (the CTM concatenated with
// the local matrix) MatrixRec::totalInverse() inverts.
fn new_image_shader(bitmap CanvasBitmap, tile_x TileMode, tile_y TileMode, linear bool, total SkAffine) CanvasShader {
	inverse := affine_invert(total) or {
		return CanvasShader{
			kind: .empty
		}
	}
	return image_shader_with_inverse(bitmap, tile_x, tile_y, linear, inverse)
}

fn image_shader_with_inverse(bitmap CanvasBitmap, tile_x TileMode, tile_y TileMode, linear bool, inverse SkAffine) CanvasShader {
	// tweak_sampling(): bilinear sampling of an integer translation is
	// nearest-neighbor sampling.
	nearest := !linear || (inverse.type_mask() <= affine_translate_mask
		&& int_cast_preserves(inverse.tx) && int_cast_preserves(inverse.ty))
	return CanvasShader{
		kind:  .image
		image: ImageShader{
			native_n32: bitmap.native_n32
			pixels:     bitmap.pixels
			width:      bitmap.width
			height:     bitmap.height
			stride:     bitmap.pitch / 4
			matrix:     inverse
			linear:     linear
			nearest:    nearest
			tile_x:     optimize_tile(tile_x, bitmap.width)
			tile_y:     optimize_tile(tile_y, bitmap.height)
			unpremul:   bitmap.display_p3 && bitmap.premultiplied
			display_p3: bitmap.display_p3
			premul:     bitmap.display_p3 || !bitmap.premultiplied
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
	return !s.mipmap_linear && !s.nearest && s.tile_x == .clamp && s.tile_y == .clamp
}

// Whether a stage lacks a lowp version: the bilinear sampler, the repeat
// tiles, the color space transform and bilerp_clamp_8888_force_highp.
fn (s &ImageShader) needs_highp() bool {
	if s.display_p3 || s.layer_decal || s.lower != unsafe { nil } {
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
	mut c := s.sample_highp(x, y)
	if s.lower != unsafe { nil } {
		lower := s.lower.sample_highp(x * s.lower_scale_x, y * s.lower_scale_y)
		for i in 0 .. 4 { c[i] = mad(lower[i] - c[i], s.lower_weight, c[i]) }
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
	mut result := [pixel.r, pixel.g, pixel.b, pixel.a]!
	if s.layer_decal {
		b := s.decal_bounds
		left := sksl_saturate(-(b.left - sx) + f32(.5))
		top := sksl_saturate(-(b.top - sy) + f32(.5))
		right := sksl_saturate(b.right - sx + f32(.5))
		bottom := sksl_saturate(b.bottom - sy + f32(.5))
		x_weight := left * top
		y_weight := x_weight * right
		weight := y_weight * bottom
		for i in 0 .. 4 { result[i] *= weight }
	}
	return result
}

fn (s &ImageShader) sample_highp(x f32, y f32) [4]f32 {
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
	return c
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
		c = s.lowp_bilerp(x, y)
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

// vqrdmulhq_s16(): (2ab + 2^15) >> 16, saturated.
fn scaled_mult(a i16, b i16) i16 {
	p := (i64(a) * i64(b) * 2 + 0x8000) >> 16
	return if p > 32767 { i16(32767) } else { i16(p) }
}

// bilerp_clamp_8888's lerpX(): the 16-bit interpolation by tx in Q15,
// halved into [0, 1/2).
fn lerp_x(left u32, right u32, tx i16) u32 {
	width := i16(u16(right - left) << 7)
	middle := u16((right + left) << 7)
	v2 := u16(u32(middle) + u32(u16(scaled_mult(tx, width))) + 1)
	return u32(v2 >> 1)
}

// lerpY(): the same in the other axis, rounded down to [0, 255].
fn lerp_y(top u32, bottom u32, ty i16) u32 {
	width := i16(i16(bottom) - i16(top))
	middle := u16(bottom + top)
	blend := u16(u32(middle) + u32(u16(scaled_mult(ty, width))) + 0x80)
	return u32(blend >> 8)
}

// The lowp bilerp_clamp_8888 stage: 16.16 sample coordinates, the four
// clamped pixels and fixed-point lerps.
fn (s &ImageShader) lowp_bilerp(x f32, y f32) [4]u32 {
	scaled_x := f32(65536.0) * x
	scaled_y := f32(65536.0) * y
	qx := neon_trunc(floor_f32(scaled_x + f32(0.5))) - 32768
	qy := neon_trunc(floor_f32(scaled_y + f32(0.5))) - 32768
	sx := int(qx >> 16)
	sy := int(qy >> 16)
	tx := i16(qx ^ 0x8000)
	ty := i16(qy ^ 0x8000)
	pixel := fn [s] (x int, y int) int {
		cx := if x < 0 { 0 } else if x > s.width - 1 { s.width - 1 } else { x }
		cy := if y < 0 { 0 } else if y > s.height - 1 { s.height - 1 } else { y }
		return (cy * s.stride + cx) * 4
	}
	l0 := pixel(sx, sy)
	r0 := pixel(sx + 1, sy)
	l1 := pixel(sx, sy + 1)
	r1 := pixel(sx + 1, sy + 1)
	mut c := [u32(0), 0, 0, 0]!
	for i in 0 .. 4 {
		top := lerp_x(u32(s.pixels[l0 + i]), u32(s.pixels[r0 + i]), tx)
		bottom := lerp_x(u32(s.pixels[l1 + i]), u32(s.pixels[r1 + i]), tx)
		c[i] = lerp_y(top, bottom, ty)
	}
	return c
}
