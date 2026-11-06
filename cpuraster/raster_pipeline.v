module cpuraster

import math

#include <math.h>

fn C.fmaf(x f32, y f32, z f32) f32

// The subset of SkRasterPipeline_opts.h (google/skia ee20d565, NEON) used by
// these CPU ports. Skia is compiled with -ffp-contract=off: only its explicit
// mad()/nmad() calls fuse, so every other operation here is a separate
// statement that clang cannot contract.

const f32_min_normal = math.f32_from_bits(0x00800000)
const pow2_23 = math.f32_from_bits(0x4b000000)
const inv_pow2_23 = math.f32_from_bits(0x34000000)
// float(0x7f800000), approx_pow2's overflow guard.
const infinity_bits_value = math.f32_from_bits(0x4eff0000)
const f32_infinity = math.f32_from_bits(0x7f800000)

// skcms_TransferFunction {g, a, b, c, d, e, f}.
struct TransferFunction {
	g f32
	a f32
	b f32
	c f32
	d f32
	e f32
	f f32
}

// SkNamedTransferFn::kSRGB, as SkColorSpaceXformSteps passes it to
// parametric to linearize, and skcms_TransferFunction_invert()'s result to
// encode.
const srgb_to_linear = TransferFunction{
	g: math.f32_from_bits(0x4019999a)
	a: math.f32_from_bits(0x3f72a76e)
	b: math.f32_from_bits(0x3d558919)
	c: math.f32_from_bits(0x3d9e8391)
	d: math.f32_from_bits(0x3d25aee6)
	e: 0
	f: 0
}
const linear_to_srgb = TransferFunction{
	g: math.f32_from_bits(0x3ed55555)
	a: math.f32_from_bits(0x3f919280)
	b: math.f32_from_bits(0x80000000)
	c: math.f32_from_bits(0x414eb852)
	d: math.f32_from_bits(0x3b4d2e31)
	e: math.f32_from_bits(0xbd612800)
	f: math.f32_from_bits(0x80000000)
}

// SkColorSpaceXformSteps' Display P3 to sRGB gamut matrix, column major as
// matrix_3x3 reads it.
const display_p3_to_srgb = [math.f32_from_bits(0x3f9cc6c9), math.f32_from_bits(0xbd2c3058),
	math.f32_from_bits(0xbca0c169), math.f32_from_bits(0xbe66847e), math.f32_from_bits(0x3f856515),
	math.f32_from_bits(0xbda10bbc), math.f32_from_bits(0x36870000), math.f32_from_bits(0x373dc800),
	math.f32_from_bits(0x3f8c9901)]!

// vfmaq_f32(a, f, m).
@[inline]
fn mad(f f32, m f32, a f32) f32 {
	return C.fmaf(f, m, a)
}

// vfmsq_f32(a, f, m): a - f*m with one rounding.
@[inline]
fn nmad(f f32, m f32, a f32) f32 {
	return C.fmaf(-f, m, a)
}

// vminq_f32/vmaxq_f32 for the finite values these stages see.
@[inline]
fn fmin(a f32, b f32) f32 {
	return if a < b { a } else { b }
}

@[inline]
fn fmax(a f32, b f32) f32 {
	return if a > b { a } else { b }
}

// vcvtnq_u32_f32 for values already clamped to the u32 range.
@[inline]
fn round_u32(value f32) u32 {
	return u32(math.round_to_even(f64(value)))
}

// to_unorm(v, scale): round(min(max(0, mad(v, scale, 0)), scale)).
@[inline]
fn to_unorm(value f32, scale int) u32 {
	scaled := mad(value, f32(scale), 0)
	return round_u32(fmin(fmax(0, scaled), f32(scale)))
}

@[inline]
fn clamp_01(value f32) f32 {
	return fmin(fmax(0, value), 1)
}

fn approx_log2(x f32) f32 {
	bits := math.f32_bits(x)
	e := f32(bits) * inv_pow2_23
	m := math.f32_from_bits((bits & 0x007fffff) | 0x3f000000)
	biased := e - math.f32_from_bits(0x42f87377)
	refined := nmad(m, math.f32_from_bits(0x3fbfbf75), biased)
	denominator := math.f32_from_bits(0x3eb444f9) + m
	correction := math.f32_from_bits(0x3fdce9a3) / denominator
	return refined - correction
}

fn approx_pow2(x f32) f32 {
	f := x - f32(math.floor(f64(x)))
	biased := x + math.f32_from_bits(0x42f28c51)
	mut approx := nmad(f, math.f32_from_bits(0x3fbebc8d), biased)
	denominator := math.f32_from_bits(0x409af5f8) - f
	correction := math.f32_from_bits(0x41ddd2fe) / denominator
	approx = approx + correction
	approx = approx * pow2_23
	approx = fmin(fmax(approx, 0), infinity_bits_value)
	return math.f32_from_bits(round_u32(approx))
}

fn approx_powf(x f32, y f32) f32 {
	if x == 0 || x == 1 {
		return x
	}
	exponent := approx_log2(x) * y
	return approx_pow2(exponent)
}

// The parametric stage: sign-preserving skcms transfer function.
fn parametric(value f32, tf TransferFunction) f32 {
	bits := math.f32_bits(value)
	sign := bits & 0x80000000
	v := math.f32_from_bits(bits ^ sign)
	linear := mad(tf.c, v, tf.f)
	base := mad(tf.a, v, tf.b)
	mut curve := approx_powf(base, tf.g)
	curve = curve + tf.e
	result := if v <= tf.d { linear } else { curve }
	return math.f32_from_bits(sign | math.f32_bits(result))
}

// Highp pixel: r, g, b, a floats.
struct FloatPixel {
mut:
	r f32
	g f32
	b f32
	a f32
}

fn (mut pixel FloatPixel) premul() {
	pixel.r = pixel.r * pixel.a
	pixel.g = pixel.g * pixel.a
	pixel.b = pixel.b * pixel.a
}

fn (mut pixel FloatPixel) unpremul() {
	inverse := f32(1) / pixel.a
	scale := if inverse < f32_infinity { inverse } else { f32(0) }
	pixel.r = pixel.r * scale
	pixel.g = pixel.g * scale
	pixel.b = pixel.b * scale
}

fn (mut pixel FloatPixel) clamp_01() {
	pixel.r = clamp_01(pixel.r)
	pixel.g = clamp_01(pixel.g)
	pixel.b = clamp_01(pixel.b)
	pixel.a = clamp_01(pixel.a)
}

fn (mut pixel FloatPixel) transfer(tf TransferFunction) {
	pixel.r = parametric(pixel.r, tf)
	pixel.g = parametric(pixel.g, tf)
	pixel.b = parametric(pixel.b, tf)
}

fn (mut pixel FloatPixel) matrix_3x3(m [9]f32) {
	red := mad(pixel.r, m[0], mad(pixel.g, m[3], pixel.b * m[6]))
	green := mad(pixel.r, m[1], mad(pixel.g, m[4], pixel.b * m[7]))
	blue := mad(pixel.r, m[2], mad(pixel.g, m[5], pixel.b * m[8]))
	pixel.r = red
	pixel.g = green
	pixel.b = blue
}

// bt709_luminance_or_luma_to_alpha: (r*0.2126 + g*0.7152) + b*0.0722.
fn (pixel FloatPixel) luminance() f32 {
	red := pixel.r * math.f32_from_bits(0x3e59b3d0)
	green := pixel.g * math.f32_from_bits(0x3f371759)
	partial := red + green
	blue := pixel.b * math.f32_from_bits(0x3d93dd98)
	return partial + blue
}

// Lowp div255_accurate() on NEON: vrshrq_n_u16(vrsraq_n_u16(v, v, 8), 8).
@[inline]
fn div255_accurate(value u32) u32 {
	accumulated := value + ((value + 128) >> 8)
	return (accumulated + 128) >> 8
}
