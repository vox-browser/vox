module cpuraster

import math

// SkRasterPipelineBlitter (google/skia ee20d565) for the constant colors
// Canvas2D fills and strokes draw with a blend mode other than source-over.
// The blit pipelines are the color, clamp_01, load_8888_dst, the blend stage,
// a coverage scale or lerp and store_8888. SkRasterPipeline runs them in its
// 16-bit lowp form when every stage has one, and in float highp otherwise;
// both are ported from the NEON (arm64) stages, where lowp's div255() is the
// exact (v + 128 + ((v + 128) >> 8)) >> 8 and highp's mad() is a fused
// multiply-add.

// SkBlendMode, in Skia's order.
pub enum BlendMode {
	clear
	src
	dst
	src_over
	dst_over
	src_in
	dst_in
	src_out
	dst_out
	src_atop
	dst_atop
	xor
	plus
	modulate
	screen
	overlay
	darken
	lighten
	color_dodge
	color_burn
	hard_light
	soft_light
	difference
	exclusion
	multiply
	hue
	saturation
	color
	luminosity
	// make_blender()'s runtime-effect blenders, after the SkBlendModes:
	// plus-darker's Safari rule and plus-lighter's saturate(src + dst).
	plus_darker
	plus_lighter
}

// skia/canvas_raster.cpp's make_blender() table: Canvas2D's composite
// operations in their encoding. Operations 26 (plus-darker) and 27
// (plus-lighter) are runtime-effect blenders.
const canvas_blend_modes = [BlendMode.src_over, .src_in, .src_out, .src_atop, .dst_over, .dst_in,
	.dst_out, .dst_atop, .plus, .src, .xor, .multiply, .screen, .overlay, .darken, .lighten,
	.color_dodge, .color_burn, .hard_light, .soft_light, .difference, .exclusion, .hue, .saturation,
	.color, .luminosity, .plus_darker, .plus_lighter]

// canvas_blend_mode returns the blend make_blender() selects for a Canvas2D
// composite operation, or none for an operation outside its table.
pub fn canvas_blend_mode(operation int) ?BlendMode {
	if operation >= 0 && operation < canvas_blend_modes.len {
		return canvas_blend_modes[operation]
	}
	return none
}

// SkBlendMode_ShouldPreScaleCoverage(mode, false), which is also
// SkBlendMode_SupportsCoverageAsAlpha().
fn blend_prescales_coverage(mode BlendMode) bool {
	return mode in [.dst, .dst_over, .plus, .dst_out, .src_atop, .src_over, .xor]
}

// SkPaint::nothingToDraw() for a paint without filters: a runtime blender
// always draws.
fn blend_draws_nothing(mode BlendMode, alpha_byte int) bool {
	return match mode {
		.src_over, .src_atop, .dst_out, .dst_over, .plus { alpha_byte == 0 }
		.dst { true }
		else { false }
	}
}

// The blend modes with a lowp stage; SkSL's raster pipeline programs run
// in highp.
fn blend_has_lowp(mode BlendMode) bool {
	return mode !in [.color_burn, .color_dodge, .soft_light, .hue, .saturation, .color, .luminosity,
		.plus_darker, .plus_lighter]
}

// paint_color_bytes is SkPaint::getColor() for SkColor channels with alpha
// alpha: SkColor4f::toSkColor() of byte * (1/255) and alpha.
fn paint_color_bytes(color u32, alpha f32) u32 {
	mut result := color4f_byte(alpha) << 24
	for shift in [u32(0), 8, 16] {
		result |= color4f_byte(f32((color >> shift) & 0xff) * inv_255) << shift
	}
	return result
}

// canvas_blitter is SkBlitter::Choose() for a solid paint on the canvas
// surface, premultiplied sRGB RGBA_8888, whose color type is never opaque:
// the paint's SkColor4f has color's channels and alpha alpha. It returns none
// for SkNullBlitter.
fn canvas_blitter(mut pixels []u8, row_bytes int, color u32, alpha f32, paint_mode BlendMode) ?Blitter {
	mut mode := paint_mode
	mut rgb := color & 0xffffff
	mut a := alpha
	if mode != .src_over {
		// CheckFastPath(): just_solid_color() tests getAlpha() == 255.
		opaque := paint_alpha_byte(alpha) == 255
		match mode {
			.src {
				if opaque {
					mode = .src_over
				}
			}
			.dst {
				return none
			}
			.dst_in {
				if opaque {
					return none
				}
			}
			else {}
		}
		// Clear draws as Src with transparent black.
		if mode == .clear {
			mode = .src
			rgb = 0
			a = 0
		}
	}
	if mode == .src_over {
		// UseLegacyBlitter(): a source-over color in bytes.
		return new_solid_blitter(mut pixels, row_bytes, paint_color_bytes(rgb, a))
	}
	return new_pipeline_blitter(mut pixels, row_bytes, rgb, a, mode)
}

// canvas_paint_blitter is SkBlitter::Choose() for the canvas paint: its
// solid SkColor, or the shader its gradient or pattern made. A shader keeps
// the raster pipeline blitter, since this build has no legacy shader
// contexts. device_bounds are the device path's bounds Draw::drawDevPath()
// passes as the stage record's destination bounds.
fn canvas_paint_blitter(mut pixels []u8, row_bytes int, color u32, shader ?CanvasShader, alpha f32, mode BlendMode, device_bounds Rect) ?Blitter {
	s := shader or { return canvas_blitter(mut pixels, row_bytes, color, alpha, mode) }
	match s.kind {
		.null_ {
			return canvas_blitter(mut pixels, row_bytes, 0xff000000, alpha, mode)
		}
		.empty {
			return none
		}
		else {}
	}
	// CheckFastPath() with a shader: only Dst draws nothing, and Clear drops
	// the shader.
	if mode == .dst {
		return none
	}
	if mode == .clear {
		return canvas_blitter(mut pixels, row_bytes, 0, 0, .clear)
	}
	if s.kind == .color {
		return new_color_shader_blitter(mut pixels, row_bytes, s.color, alpha, mode)
	}
	if s.kind == .image {
		// UseLegacyBlitter() for source-over, then the legacy shader context
		// when the image shader can make one.
		if mode == .src_over {
			if state := legacy_image_context(s.image, paint_alpha_byte(alpha)) {
				return new_legacy_shader_blitter(mut pixels, row_bytes, state)
			}
		}
		mut image := s.image
		image.check_device_bounds(device_bounds)
		return new_image_blitter(mut pixels, row_bytes, image, alpha, mode)
	}
	return new_gradient_blitter(mut pixels, row_bytes, s.gradient, alpha, mode)
}

pub struct PipelineBlitter {
	mode      BlendMode
	lowp      bool
	prescale  bool
	memset    bool
	row_bytes int
	// store_8888 of the color, which Src blits write directly.
	memset_color u32
	// The uniform_color context: 8-bit values in 16-bit lanes for lowp, the
	// premultiplied floats for highp.
	lr u32
	lg u32
	lb u32
	la u32
	fr f32
	fg f32
	fb f32
	fa f32
	// A gradient or image source instead of the constant color, and the
	// paint alpha's scale_1_float after it.
	shaded bool
	shader GradientShader
	imaged bool
	image  ImageShader
	scaled bool
	scale  f32
	// An SkColorFilterShader's filter stages after the scale, and whether
	// the shaded color is known opaque when they start.
	filtered      bool
	filter        ColorFilter
	filter_opaque bool
mut:
	pixels []u8
}

// new_pipeline_blitter is SkRasterPipelineBlitter::Create() for an
// unpremultiplied paint color (SkColor channels, float alpha) and mode.
fn new_pipeline_blitter(mut pixels []u8, row_bytes int, rgb u32, alpha f32, mode BlendMode) PipelineBlitter {
	// appendConstantColor() of SkColor4f::premul().
	mut c := [f32((rgb >> 16) & 0xff) * inv_255, f32((rgb >> 8) & 0xff) * inv_255,
		f32(rgb & 0xff) * inv_255, alpha]!
	for i in 0 .. 3 {
		c[i] = c[i] * alpha
	}
	return new_constant_blitter(mut pixels, row_bytes, c, 1, mode)
}

// new_color_shader_blitter is Create() for SkShaders::Color(): its
// premultiplied color, then scale_1_float by the paint alpha.
fn new_color_shader_blitter(mut pixels []u8, row_bytes int, color [4]f32, alpha f32, mode BlendMode) PipelineBlitter {
	mut c := color
	for i in 0 .. 3 {
		c[i] = c[i] * c[3]
	}
	return new_constant_blitter(mut pixels, row_bytes, c, alpha, mode)
}

// new_constant_blitter: the constant pipeline (the premultiplied color,
// scale_1_float when alpha is not 1, clamp_01 and store_f32) runs once in
// highp and its result becomes the constant; an opaque result turns
// source-over into Src.
fn new_constant_blitter(mut pixels []u8, row_bytes int, premul [4]f32, alpha f32, mode_in BlendMode) PipelineBlitter {
	mut c := premul
	black := c[0] == 0 && c[1] == 0 && c[2] == 0 && c[3] == 1
	white := c[0] == 1 && c[1] == 1 && c[2] == 1 && c[3] == 1
	if black || white {
		v := if white { f32(1) } else { f32(0) }
		c = [v, v, v, f32(1)]!
	}
	if alpha != 1 {
		for i in 0 .. 4 {
			c[i] = c[i] * alpha
		}
	}
	for i in 0 .. 4 {
		c[i] = neon_min(neon_max(0, c[i]), 1)
	}
	mode := if mode_in == .src_over && c[3] == 1 { BlendMode.src } else { mode_in }
	mut lanes := [u32(0), 0, 0, 0]!
	if c[0] == 0 && c[1] == 0 && c[2] == 0 && c[3] == 1 {
		lanes = [u32(0), 0, 0, 255]!
	} else if c[0] == 1 && c[1] == 1 && c[2] == 1 && c[3] == 1 {
		lanes = [u32(255), 255, 255, 255]!
	} else {
		for i in 0 .. 4 {
			scaled := c[i] * f32(255)
			biased := scaled + f32(0.5)
			lanes[i] = u32(u16(biased))
		}
	}
	// appendConstantColor(): uniform_color, with lowp, only for a color in
	// premultiplied range; a filtered color can leave it (a channel above
	// alpha), and unbounded_uniform_color runs in highp.
	bounded := c[0] >= 0 && c[0] <= c[3] && c[1] >= 0 && c[1] <= c[3] && c[2] >= 0
		&& c[2] <= c[3]
	// A constant Src color is memset; store_8888 clamps its lanes to 255.
	mut memset_color := u32(0)
	for i in 0 .. 4 {
		lane := if bounded { lowp_min(lanes[i], 255) } else { to_unorm(c[i], 255) }
		memset_color |= lane << (8 * u32(i))
	}
	return PipelineBlitter{
		mode:         mode
		lowp:         blend_has_lowp(mode) && bounded
		prescale:     blend_prescales_coverage(mode)
		memset:       mode == .src
		row_bytes:    row_bytes
		memset_color: memset_color
		lr:           lanes[0]
		lg:           lanes[1]
		lb:           lanes[2]
		la:           lanes[3]
		fr:           c[0]
		fg:           c[1]
		fb:           c[2]
		fa:           c[3]
		pixels:       pixels
	}
}

// new_gradient_blitter is Create() for a gradient shader at paint alpha
// alpha: lowp unless the blend mode or a conical stage needs floats, and
// source-over becomes Src for an opaque gradient at full alpha.
fn new_gradient_blitter(mut pixels []u8, row_bytes int, shader GradientShader, alpha f32, mode_in BlendMode) PipelineBlitter {
	mode := if mode_in == .src_over && shader.opaque && alpha == 1 {
		BlendMode.src
	} else {
		mode_in
	}
	return PipelineBlitter{
		mode:      mode
		lowp:      blend_has_lowp(mode) && !shader.needs_highp()
		prescale:  blend_prescales_coverage(mode)
		row_bytes: row_bytes
		shaded:    true
		shader:    shader
		scaled:    alpha != 1
		scale:     alpha
		pixels:    pixels
	}
}

// new_image_blitter is Create() for an image shader at paint alpha alpha:
// lowp unless the blend mode or a sampling stage needs floats. Image
// shaders never report opacity here: Canvas2D images are not kOpaque and
// decal tiles are transparent outside them.
fn new_image_blitter(mut pixels []u8, row_bytes int, shader ImageShader, alpha f32, mode BlendMode) PipelineBlitter {
	return PipelineBlitter{
		mode:      mode
		lowp:      blend_has_lowp(mode) && !shader.needs_highp()
		prescale:  blend_prescales_coverage(mode)
		row_bytes: row_bytes
		imaged:    true
		image:     shader
		scaled:    alpha != 1
		scale:     alpha
		pixels:    pixels
	}
}

@[inline]
fn (b &PipelineBlitter) offset(x int, y int) int {
	return y * b.row_bytes + x * 4
}

// Coverage stages: none for blitRect(), the float coverage of blitAntiH()
// (scale_1_float or lerp_1_float) and the A8 coverage of blitMask()
// (scale_u8 or lerp_u8).
enum CoverageKind {
	none
	float
	mask
}

// blit runs the pipeline over count pixels from (x, y).
fn (mut b PipelineBlitter) blit(x int, y int, count int, kind CoverageKind, coverage u8) {
	offset := b.offset(x, y)
	for i in 0 .. count {
		o := offset + i * 4
		if b.lowp {
			b.blit_lowp(x + i, y, o, kind, coverage)
		} else {
			b.blit_highp(x + i, y, o, kind, coverage)
		}
	}
}

fn (mut b PipelineBlitter) blit_h(x int, y int, width int) {
	b.blit_rect(x, y, width, 1)
}

fn (mut b PipelineBlitter) blit_rect(x int, y int, width int, height int) {
	for row in 0 .. height {
		offset := b.offset(x, y + row)
		if b.memset {
			for i in 0 .. width {
				store32(mut b.pixels, offset + i * 4, b.memset_color)
			}
		} else {
			b.blit(x, y + row, width, .none, 0)
		}
	}
}

fn (mut b PipelineBlitter) blit_anti_h(x_in int, y int, mut aa []u8, mut runs []i16) {
	mut x := x_in
	mut i := 0
	for {
		run := int(runs[i])
		if run <= 0 {
			return
		}
		match aa[i] {
			0 {}
			255 {
				b.blit_rect(x, y, run, 1)
			}
			else {
				b.blit(x, y, run, .float, aa[i])
			}
		}
		x += run
		i += run
	}
}

// blitV(), blitAntiH2() and blitAntiV2() blit A8 masks.
fn (mut b PipelineBlitter) blit_v(x int, y int, height int, alpha u8) {
	for row in 0 .. height {
		b.blit(x, y + row, 1, .mask, alpha)
	}
}

fn (mut b PipelineBlitter) blit_anti_h2(x int, y int, a0 u8, a1 u8) {
	b.blit(x, y, 1, .mask, a0)
	b.blit(x + 1, y, 1, .mask, a1)
}

fn (mut b PipelineBlitter) blit_anti_v2(x int, y int, a0 u8, a1 u8) {
	b.blit(x, y, 1, .mask, a0)
	b.blit(x, y + 1, 1, .mask, a1)
}

fn (mut b PipelineBlitter) blit_anti_rect(x int, y int, width int, height int, left_alpha u8, right_alpha u8) {
	default_blit_anti_rect(mut b, x, y, width, height, left_alpha, right_alpha)
}

fn (mut b PipelineBlitter) blit_mask(mask &Mask, clip IRect) {
	for row in 0 .. clip.height() {
		src := mask.index(clip.left, clip.top + row)
		for i in 0 .. clip.width() {
			b.blit(clip.left + i, clip.top + row, 1, .mask, mask.image[src + i])
		}
	}
}

// Lowp: U16 lanes that wrap like the vector arithmetic, kept in u32.

@[inline]
fn u16w(v u32) u32 {
	return v & 0xffff
}

@[inline]
fn lowp_inv(v u32) u32 {
	return u16w(255 - v)
}

@[inline]
fn lowp_min(a u32, b u32) u32 {
	return if a < b { a } else { b }
}

@[inline]
fn lowp_max(a u32, b u32) u32 {
	return if a < b { b } else { a }
}

// div255() on NEON: vrshrq_n_u16(vrsraq_n_u16(v, v, 8), 8). The
// accumulation wraps; the rounding shifts do not.
@[inline]
fn lowp_div255(v u32) u32 {
	accumulated := u16w(v + ((v + 128) >> 8))
	return (accumulated + 128) >> 8
}

// from_float(): U16(f * 255 + 0.5).
@[inline]
fn lowp_from_float(f f32) u32 {
	scaled := f * f32(255)
	biased := scaled + f32(0.5)
	return u32(u16(biased))
}

// lerp(from, to, t): div255(from * inv(t) + to * t).
@[inline]
fn lowp_lerp(from u32, to u32, t u32) u32 {
	return lowp_div255(u16w(u16w(from * lowp_inv(t)) + u16w(to * t)))
}

// The per-channel lowp blend modes, s and d being one channel of the source
// and destination.
fn lowp_channel(mode BlendMode, s u32, d u32, sa u32, da u32) u32 {
	return match mode {
		.src_atop {
			lowp_div255(u16w(u16w(s * da) + u16w(d * lowp_inv(sa))))
		}
		.dst_atop {
			lowp_div255(u16w(u16w(d * sa) + u16w(s * lowp_inv(da))))
		}
		.src_in {
			lowp_div255(u16w(s * da))
		}
		.dst_in {
			lowp_div255(u16w(d * sa))
		}
		.src_out {
			lowp_div255(u16w(s * lowp_inv(da)))
		}
		.dst_out {
			lowp_div255(u16w(d * lowp_inv(sa)))
		}
		.src_over {
			u16w(s + lowp_div255(u16w(d * lowp_inv(sa))))
		}
		.dst_over {
			u16w(d + lowp_div255(u16w(s * lowp_inv(da))))
		}
		.modulate {
			lowp_div255(u16w(s * d))
		}
		.multiply {
			lowp_div255(u16w(u16w(u16w(s * lowp_inv(da)) + u16w(d * lowp_inv(sa))) + u16w(s * d)))
		}
		.plus {
			lowp_min(u16w(s + d), 255)
		}
		.screen {
			u16w(u16w(s + d) - lowp_div255(u16w(s * d)))
		}
		.xor {
			lowp_div255(u16w(u16w(s * lowp_inv(da)) + u16w(d * lowp_inv(sa))))
		}
		.darken {
			u16w(u16w(s + d) - lowp_div255(lowp_max(u16w(s * da), u16w(d * sa))))
		}
		.lighten {
			u16w(u16w(s + d) - lowp_div255(lowp_min(u16w(s * da), u16w(d * sa))))
		}
		.difference {
			u16w(u16w(s + d) - u16w(2 * lowp_div255(lowp_min(u16w(s * da), u16w(d * sa)))))
		}
		.exclusion {
			u16w(u16w(s + d) - u16w(2 * lowp_div255(u16w(s * d))))
		}
		.hard_light, .overlay {
			lowp_light(mode, s, d, sa, da)
		}
		else {
			0
		}
	}
}

// hardlight and overlay: div255(s*inv(da) + d*inv(sa) + if_then_else(2*s <= sa
// (2*d <= da for overlay), 2*s*d, sa*da - 2*(sa-s)*(da-d))).
fn lowp_light(mode BlendMode, s u32, d u32, sa u32, da u32) u32 {
	base := u16w(u16w(s * lowp_inv(da)) + u16w(d * lowp_inv(sa)))
	dark := if mode == .hard_light { u16w(2 * s) <= sa } else { u16w(2 * d) <= da }
	term := if dark {
		u16w(u16w(2 * s) * d)
	} else {
		u16w(u16w(sa * da) - u16w(u16w(2 * u16w(sa - s)) * u16w(da - d)))
	}
	return lowp_div255(u16w(base + term))
}

// Modes that blend colors per channel and alpha as srcover:
// a + div255(da * inv(a)).
fn lowp_alpha_is_srcover(mode BlendMode) bool {
	return mode in [.darken, .lighten, .difference, .exclusion, .hard_light, .overlay]
}

fn (mut b PipelineBlitter) blit_lowp(px int, py int, o int, kind CoverageKind, coverage u8) {
	// The color or shader, scale_1_float, and clamp_01: min(v, 255).
	mut src := if b.imaged {
		b.image.shade_lowp(px, py)
	} else if b.shaded {
		b.shader.shade_lowp(px, py)
	} else {
		[b.lr, b.lg, b.lb, b.la]!
	}
	if b.scaled {
		alpha := lowp_from_float(b.scale)
		for i in 0 .. 4 {
			src[i] = lowp_div255(u16w(src[i] * alpha))
		}
	}
	mut r := lowp_min(src[0], 255)
	mut g := lowp_min(src[1], 255)
	mut bl := lowp_min(src[2], 255)
	mut a := lowp_min(src[3], 255)
	c := match kind {
		.none { u32(0) }
		.float { lowp_from_float(f32(coverage) * inv_255) }
		.mask { u32(coverage) }
	}
	if kind != .none && b.prescale {
		r = lowp_div255(u16w(r * c))
		g = lowp_div255(u16w(g * c))
		bl = lowp_div255(u16w(bl * c))
		a = lowp_div255(u16w(a * c))
	}
	dr := u32(b.pixels[o])
	dg := u32(b.pixels[o + 1])
	db := u32(b.pixels[o + 2])
	da := u32(b.pixels[o + 3])
	if b.mode != .src {
		nr := lowp_channel(b.mode, r, dr, a, da)
		ng := lowp_channel(b.mode, g, dg, a, da)
		nb := lowp_channel(b.mode, bl, db, a, da)
		na := if lowp_alpha_is_srcover(b.mode) {
			u16w(a + lowp_div255(u16w(da * lowp_inv(a))))
		} else {
			lowp_channel(b.mode, a, da, a, da)
		}
		r, g, bl, a = nr, ng, nb, na
	}
	if kind != .none && !b.prescale {
		r = lowp_lerp(dr, r, c)
		g = lowp_lerp(dg, g, c)
		bl = lowp_lerp(db, bl, c)
		a = lowp_lerp(da, a, c)
	}
	b.pixels[o] = u8(lowp_min(r, 255))
	b.pixels[o + 1] = u8(lowp_min(g, 255))
	b.pixels[o + 2] = u8(lowp_min(bl, 255))
	b.pixels[o + 3] = u8(lowp_min(a, 255))
}

// Highp: NEON float lanes.

const f32_nan = math.f32_from_bits(0x7fc00000)

// vminq_f32: NaN when either input is NaN, and -0 below +0.
@[inline]
fn neon_min(a f32, b f32) f32 {
	if a != a || b != b {
		return f32_nan
	}
	if a == b {
		return if math.f32_bits(a) >> 31 != 0 { a } else { b }
	}
	return if a < b { a } else { b }
}

// vmaxq_f32: NaN when either input is NaN, and +0 above -0.
@[inline]
fn neon_max(a f32, b f32) f32 {
	if a != a || b != b {
		return f32_nan
	}
	if a == b {
		return if math.f32_bits(a) >> 31 == 0 { a } else { b }
	}
	return if a > b { a } else { b }
}

// vrecpeq_f32: the Arm FPRecipEstimate() pseudocode for single precision
// with FPCR.FZ clear, which is 8 bits of RecipEstimate().
fn recip_estimate(value f32) f32 {
	bits := math.f32_bits(value)
	sign := bits & 0x80000000
	mut exp := int((bits >> 23) & 0xff)
	mut fraction := bits & 0x7fffff
	if exp == 0xff {
		return if fraction != 0 { f32_nan } else { math.f32_from_bits(sign) }
	}
	if exp == 0 && fraction < 0x200000 {
		// Zero, or below 2^-128: the estimate overflows to infinity.
		return math.f32_from_bits(sign | 0x7f800000)
	}
	if exp == 0 {
		if (fraction >> 22) & 1 == 0 {
			exp = -1
			fraction = (fraction & 0x1fffff) << 2
		} else {
			fraction = (fraction & 0x3fffff) << 1
		}
	}
	scaled := 0x100 | (fraction >> 15)
	a := scaled * 2 + 1
	estimate := ((u32(1) << 19) / a + 1) / 2
	mut result_exp := 253 - exp
	mut result_fraction := (estimate & 0xff) << 15
	if result_exp == 0 {
		result_fraction = 0x400000 | (result_fraction >> 1)
	} else if result_exp == -1 {
		result_fraction = 0x200000 | (result_fraction >> 2)
		result_exp = 0
	}
	return math.f32_from_bits(sign | (u32(result_exp) << 23) | result_fraction)
}

// vrecpsq_f32: 2 - a*b fused, and 2 for infinity times zero.
fn recip_step(a f32, b f32) f32 {
	a_inf := math.f32_bits(a) & 0x7fffffff == 0x7f800000
	b_inf := math.f32_bits(b) & 0x7fffffff == 0x7f800000
	if (a_inf && b == 0) || (a == 0 && b_inf) {
		return 2
	}
	return nmad(a, b, 2)
}

// rcp_fast(): one Newton-Raphson step from the estimate.
fn rcp_fast(v f32) f32 {
	e := recip_estimate(v)
	step := recip_step(v, e)
	return step * e
}

@[inline]
fn highp_inv(v f32) f32 {
	return f32(1) - v
}

// vcvtnq_u32_f32 of min(max(0, mad(v, 255, 0)), 255): NaN converts to 0.
@[inline]
fn highp_to_byte(v f32) u8 {
	clamped := neon_min(neon_max(0, mad(v, 255, 0)), 255)
	if clamped != clamped {
		return 0
	}
	return u8(round_u32(clamped))
}

// The blend modes' unfused products: Skia compiles them with
// -ffp-contract=off, so each multiply is its own statement here, where clang
// would otherwise fuse it into the following add.

fn highp_color_burn(s f32, d f32, sa f32, da f32) f32 {
	src_term := s * highp_inv(da)
	dst_term := d * highp_inv(sa)
	if d == da {
		return d + src_term
	}
	if s == 0 {
		return dst_term
	}
	q := (da - d) * sa
	ratio := q * rcp_fast(s)
	m := neon_min(da, ratio)
	burned := sa * (da - m)
	partial := burned + src_term
	return partial + dst_term
}

fn highp_color_dodge(s f32, d f32, sa f32, da f32) f32 {
	src_term := s * highp_inv(da)
	dst_term := d * highp_inv(sa)
	if d == 0 {
		return src_term
	}
	if s == sa {
		return s + dst_term
	}
	q := d * sa
	ratio := q * rcp_fast(sa - s)
	dodged := sa * neon_min(da, ratio)
	partial := dodged + src_term
	return partial + dst_term
}

fn highp_soft_light(s f32, d f32, sa f32, da f32) f32 {
	m := if da > 0 { d / da } else { f32(0) }
	s2 := s + s
	m2 := m + m
	m4 := m2 + m2
	// Case 1, a dark source.
	darkening := (s2 - sa) * (f32(1) - m)
	dark_sum := sa + darkening
	dark_src := d * dark_sum
	// Case 2, a light source and a dark destination.
	square := m4 * m4
	cubic := (square + m4) * (m - f32(1))
	seven_m := f32(7) * m
	dark_dst := cubic + seven_m
	// Case 3, both light.
	lite_dst := C.sqrtf(m) - m
	d2 := d + d
	d4 := d2 + d2
	selected := if d4 <= da { dark_dst } else { lite_dst }
	spread := da * (s2 - sa)
	dst_alpha_term := d * sa
	light := spread * selected
	lite_src := dst_alpha_term + light
	src_term := s * highp_inv(da)
	dst_term := d * highp_inv(sa)
	base := src_term + dst_term
	chosen := if s2 <= sa { dark_src } else { lite_src }
	return base + chosen
}

const lum_r = math.f32_from_bits(0x3e99999a) // 0.30f
const lum_g = math.f32_from_bits(0x3f170a3d) // 0.59f
const lum_b = math.f32_from_bits(0x3de147ae) // 0.11f

@[inline]
fn highp_sat(r f32, g f32, b f32) f32 {
	return neon_max(r, neon_max(g, b)) - neon_min(r, neon_min(g, b))
}

@[inline]
fn highp_lum(r f32, g f32, b f32) f32 {
	return mad(r, lum_r, mad(g, lum_g, b * lum_b))
}

fn set_sat(mut c [3]f32, s f32) {
	mn := neon_min(c[0], neon_min(c[1], c[2]))
	mx := neon_max(c[0], neon_max(c[1], c[2]))
	sat := mx - mn
	scale := if sat == 0 { f32(0) } else { s * rcp_fast(sat) }
	for i in 0 .. 3 {
		c[i] = (c[i] - mn) * scale
	}
}

fn set_lum(mut c [3]f32, l f32) {
	diff := l - highp_lum(c[0], c[1], c[2])
	for i in 0 .. 3 {
		c[i] = c[i] + diff
	}
}

fn clip_color(mut c [3]f32, a f32) {
	mn := neon_min(c[0], neon_min(c[1], c[2]))
	mx := neon_max(c[0], neon_max(c[1], c[2]))
	l := highp_lum(c[0], c[1], c[2])
	mn_scale := l * rcp_fast(l - mn)
	mx_scale := (a - l) * rcp_fast(mx - l)
	clip_low := mn < 0 && l != mn
	clip_high := mx > a && l != mx
	for i in 0 .. 3 {
		mut v := c[i]
		if clip_low {
			v = mad(mn_scale, v - l, l)
		}
		if clip_high {
			v = mad(mx_scale, v - l, l)
		}
		c[i] = neon_max(v, 0)
	}
}

// The separable highp blend modes for one channel; products sit in their own
// statements so that only the explicit mad()/nmad() calls fuse.
fn highp_channel(mode BlendMode, s f32, d f32, sa f32, da f32) f32 {
	match mode {
		.src_atop {
			t := d * highp_inv(sa)
			return mad(s, da, t)
		}
		.dst_atop {
			t := s * highp_inv(da)
			return mad(d, sa, t)
		}
		.src_in {
			return s * da
		}
		.dst_in {
			return d * sa
		}
		.src_out {
			return s * highp_inv(da)
		}
		.dst_out {
			return d * highp_inv(sa)
		}
		.src_over {
			return mad(d, highp_inv(sa), s)
		}
		.dst_over {
			return mad(s, highp_inv(da), d)
		}
		.modulate {
			return s * d
		}
		.multiply {
			t := d * highp_inv(sa)
			return mad(s, d, mad(s, highp_inv(da), t))
		}
		.plus {
			sum := s + d
			return neon_min(sum, 1)
		}
		.screen {
			sum := s + d
			return nmad(s, d, sum)
		}
		.xor {
			t := d * highp_inv(sa)
			return mad(s, highp_inv(da), t)
		}
		.darken, .lighten, .difference {
			sum := s + d
			sda := s * da
			dsa := d * sa
			if mode == .darken {
				return sum - neon_max(sda, dsa)
			}
			m := neon_min(sda, dsa)
			if mode == .lighten {
				return sum - m
			}
			twice := m + m
			return sum - twice
		}
		.exclusion {
			sum := s + d
			sd := s * d
			twice := sd + sd
			return sum - twice
		}
		.hard_light, .overlay {
			a1 := s * highp_inv(da)
			a2 := d * highp_inv(sa)
			base := a1 + a2
			dark := if mode == .hard_light { s + s <= sa } else { d + d <= da }
			mut term := f32(0)
			if dark {
				sd := s * d
				term = sd + sd
			} else {
				sada := sa * da
				q := (da - d) * (sa - s)
				term = sada - (q + q)
			}
			return base + term
		}
		else {
			return 0
		}
	}
}

// SkSL's saturate(): clamp(x, 0, 1) as min(max(x, 0), 1).
@[inline]
fn sksl_saturate(x f32) f32 {
	return neon_min(neon_max(x, 0), 1)
}

fn (mut b PipelineBlitter) blit_highp(px int, py int, o int, kind CoverageKind, coverage u8) {
	// The color or shader, scale_1_float, and clamp_01.
	mut src := if b.imaged {
		b.image.shade_highp(px, py)
	} else if b.shaded {
		b.shader.shade_highp(px, py)
	} else {
		[b.fr, b.fg, b.fb, b.fa]!
	}
	if b.scaled {
		for i in 0 .. 4 {
			src[i] = src[i] * b.scale
		}
	}
	if b.filtered {
		src = b.filter.apply(src, b.filter_opaque)
	}
	mut r := neon_min(neon_max(0, src[0]), 1)
	mut g := neon_min(neon_max(0, src[1]), 1)
	mut bl := neon_min(neon_max(0, src[2]), 1)
	mut a := neon_min(neon_max(0, src[3]), 1)
	// Coverage prescaled before the blend: scale_1_float or scale_u8.
	t := f32(coverage) * inv_255
	if kind != .none && b.prescale {
		r = r * t
		g = g * t
		bl = bl * t
		a = a * t
	}
	// load_8888_dst.
	dr := f32(b.pixels[o]) * inv_255
	dg := f32(b.pixels[o + 1]) * inv_255
	db := f32(b.pixels[o + 2]) * inv_255
	da := f32(b.pixels[o + 3]) * inv_255
	mut out := [f32(0), 0, 0, 0]!
	match b.mode {
		.src {
			out = [r, g, bl, a]!
		}
		.color_burn, .color_dodge, .soft_light {
			sc := [r, g, bl]!
			dc := [dr, dg, db]!
			for i in 0 .. 3 {
				out[i] = match b.mode {
					.color_burn { highp_color_burn(sc[i], dc[i], a, da) }
					.color_dodge { highp_color_dodge(sc[i], dc[i], a, da) }
					else { highp_soft_light(sc[i], dc[i], a, da) }
				}
			}
			out[3] = mad(da, highp_inv(a), a)
		}
		.plus_lighter {
			// saturate(source + destination), saturate as SkSL's
			// min(max(x, 0), 1).
			src_c := [r, g, bl, a]!
			dst_c := [dr, dg, db, da]!
			for i in 0 .. 4 {
				out[i] = sksl_saturate(src_c[i] + dst_c[i])
			}
		}
		.plus_darker {
			// saturate(saturate(da + sa) - saturate(da - destination) -
			// saturate(sa - source)).
			alphas := sksl_saturate(da + a)
			src_c := [r, g, bl, a]!
			dst_c := [dr, dg, db, da]!
			for i in 0 .. 4 {
				dst_term := sksl_saturate(da - dst_c[i])
				src_term := sksl_saturate(a - src_c[i])
				partial := alphas - dst_term
				out[i] = sksl_saturate(partial - src_term)
			}
		}
		.hue, .saturation, .color, .luminosity {
			mut c := match b.mode {
				.hue { [r * a, g * a, bl * a]! }
				.color { [r * da, g * da, bl * da]! }
				else { [dr * a, dg * a, db * a]! }
			}
			match b.mode {
				.hue {
					set_sat(mut c, highp_sat(dr, dg, db) * a)
					set_lum(mut c, highp_lum(dr, dg, db) * a)
				}
				.saturation {
					set_sat(mut c, highp_sat(r, g, bl) * da)
					set_lum(mut c, highp_lum(dr, dg, db) * a)
				}
				.color {
					set_lum(mut c, highp_lum(dr, dg, db) * a)
				}
				else {
					set_lum(mut c, highp_lum(r, g, bl) * da)
				}
			}
			clip_color(mut c, a * da)
			out[0] = mad(r, highp_inv(da), mad(dr, highp_inv(a), c[0]))
			out[1] = mad(g, highp_inv(da), mad(dg, highp_inv(a), c[1]))
			out[2] = mad(bl, highp_inv(da), mad(db, highp_inv(a), c[2]))
			out[3] = a + nmad(a, da, da)
		}
		else {
			src_c := [r, g, bl]!
			dst_c := [dr, dg, db]!
			for i in 0 .. 3 {
				out[i] = highp_channel(b.mode, src_c[i], dst_c[i], a, da)
			}
			out[3] = if lowp_alpha_is_srcover(b.mode) {
				mad(da, highp_inv(a), a)
			} else {
				highp_channel(b.mode, a, da, a, da)
			}
		}
	}
	if kind != .none && !b.prescale {
		// lerp_1_float or lerp_u8: mad(to - from, t, from).
		dst := [dr, dg, db, da]!
		for i in 0 .. 4 {
			out[i] = mad(out[i] - dst[i], t, dst[i])
		}
	}
	for i in 0 .. 4 {
		b.pixels[o + i] = highp_to_byte(out[i])
	}
}
