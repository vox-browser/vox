module cpuraster

import crypto.sha256
import math

// A premultiplied background whose pixels include transparent, opaque and
// channel-equals-alpha values, which the blend modes treat specially.
fn composite_test_background(width int, height int) []u8 {
	mut px := []u8{len: width * height * 4}
	for y in 0 .. height {
		for x in 0 .. width {
			o := (y * width + x) * 4
			kind := (x + y) % 7
			a := match kind {
				0 { 0 }
				1 { 255 }
				else { (x * 11 + y * 5) % 256 }
			}
			px[o + 3] = u8(a)
			px[o] = u8(a * x / width)
			px[o + 1] = if y % 3 == 0 { u8(a) } else { u8(a * y / height) }
			px[o + 2] = if x % 4 == 0 { u8(0) } else { u8(a / 2) }
		}
	}
	return px
}

fn composite_test_segment(kind int, values []f32) []f32 {
	mut segment := [f32(kind)]
	segment << values
	for segment.len < 12 {
		segment << 0
	}
	return segment
}

// A curved shape with a self-intersecting cubic.
fn composite_test_shape() []f32 {
	mut s := []f32{}
	s << composite_test_segment(0, [f32(6), 4])
	s << composite_test_segment(2, [f32(40), 6, 44, 2])
	s << composite_test_segment(3, [f32(30), 38, 4, 2, 46, 34])
	s << composite_test_segment(1, [f32(3), 36])
	s << composite_test_segment(5, [])
	return s
}

const composite_test_transform = [f32(0.97), 0.12, -0.1, 0.95, 1.5, 2.25]!

fn composite_fill_hash(mode BlendMode, color u32, alpha f32) string {
	mut px := composite_test_background(48, 40)
	assert fill_canvas_path(mut px, 48, 40, 192, 2, canvas_path(composite_test_shape(), false),
		composite_test_transform, color, none, alpha, mode, 0, [])
	return sha256.sum(px).hex()[..16]
}

fn composite_stroke_hash(mode BlendMode, color u32, alpha f32, line_width f32, dashes []f32, clips []Path) string {
	mut px := composite_test_background(48, 40)
	assert stroke_canvas_path(mut px, 48, 40, 192, 2, canvas_path(composite_test_shape(),
		false), composite_test_transform, color, none, alpha, mode, 0, line_width, .round, .miter, 10,
		dashes, 1.5, clips)
	return sha256.sum(px).hex()[..16]
}

fn test_canvas_composite_operations_map_to_skia_blend_modes() {
	assert canvas_blend_mode(0) or { BlendMode.clear } == .src_over
	assert canvas_blend_mode(8) or { BlendMode.clear } == .plus
	assert canvas_blend_mode(9) or { BlendMode.clear } == .src
	assert canvas_blend_mode(16) or { BlendMode.clear } == .color_dodge
	assert canvas_blend_mode(25) or { BlendMode.clear } == .luminosity
	// plus-darker and plus-lighter are runtime-effect blenders.
	assert canvas_blend_mode(26) == none
	assert canvas_blend_mode(27) == none
	assert canvas_blend_mode(-1) == none
}

// FRECPE results read from arm64 hardware, including zeros, infinity, a
// denormal below 2^-128, denormals with each fraction form and an input whose
// estimate is denormal.
fn test_reciprocal_estimate_matches_frecpe() {
	cases := [[u32(0x3f800000), 0x3f7f8000], [u32(0x40400000), 0x3eaa8000],
		[u32(0x00000000), 0x7f800000], [u32(0x80000000), 0xff800000], [u32(0x7f800000), 0x00000000],
		[u32(0x00100000), 0x7f800000], [u32(0x00400000), 0x7eff8000], [u32(0x7e800000), 0x007fc000],
		[u32(0x3f7f0000), 0x3f808000], [u32(0xbe99999a), 0xc0550000]]
	for c in cases {
		assert math.f32_bits(recip_estimate(math.f32_from_bits(c[0]))) == c[1]
	}
	assert recip_estimate(math.f32_from_bits(0x7fc00000)) != recip_estimate(math.f32_from_bits(0x7fc00000))
}

// rcp_fast() results read from arm64 hardware: the estimate after one
// Newton-Raphson step, which differs from division in the low bits.
fn test_fast_reciprocal_matches_neon() {
	cases := [[u32(0x40400000), 0x3eaaaaa0], [u32(0x3f333333), 0x3fb6db67],
		[u32(0x3a83126f), 0x4479ffbe], [u32(0x00000000), 0x7f800000], [u32(0x7f800000), 0x00000000],
		[u32(0x3f19999a), 0x3fd55533]]
	for c in cases {
		assert math.f32_bits(rcp_fast(math.f32_from_bits(c[0]))) == c[1]
	}
}

fn test_neon_min_and_max_propagate_nan_and_order_zeros() {
	negative_zero := math.f32_from_bits(0x80000000)
	assert math.f32_bits(neon_min(0, negative_zero)) == 0x80000000
	assert math.f32_bits(neon_max(negative_zero, 0)) == 0
	nan := neon_min(1, f32_nan)
	assert nan != nan
	assert highp_to_byte(f32_nan) == 0
}

fn test_skia_fast_paths_for_solid_colors() {
	background := composite_test_background(48, 40)
	// Opaque destination-in multiplies by one and draws nothing.
	mut kept := background.clone()
	assert fill_canvas_path(mut kept, 48, 40, 192, 2, canvas_path(composite_test_shape(), false),
		composite_test_transform, 0xff336699, none, 1, .dst_in, 0, [])
	assert kept == background
	// An opaque copy draws as source-over.
	mut copied := background.clone()
	mut over := background.clone()
	assert fill_canvas_path(mut copied, 48, 40, 192, 2, canvas_path(composite_test_shape(),
		false), composite_test_transform, 0xff336699, none, 1, .src, 0, [])
	assert fill_canvas_path(mut over, 48, 40, 192, 2, canvas_path(composite_test_shape(), false),
		composite_test_transform, 0xff336699, none, 1, .src_over, 0, [])
	assert copied == over && copied != background
	// SkPaint::nothingToDraw() for a transparent source-atop, but not for
	// source-in, which clears what it covers.
	mut atop := background.clone()
	assert fill_canvas_path(mut atop, 48, 40, 192, 2, canvas_path(composite_test_shape(), false),
		composite_test_transform, 0xff336699, none, 0, .src_atop, 0, [])
	assert atop == background
	mut cleared := background.clone()
	assert fill_canvas_path(mut cleared, 48, 40, 192, 2, canvas_path(composite_test_shape(),
		false), composite_test_transform, 0xff336699, none, 0, .src_in, 0, [])
	assert cleared != background
}

// Hashes of vox_skia_canvas_path()'s output with LibWeb Skia for the same
// draws and background (test_cpu_raster.sh compares random ones).
fn test_lowp_composite_fills_match_skia() {
	assert composite_fill_hash(.multiply, 0xff3070c0, 0.8) == '58c30f38dfc1e2f9'
	assert composite_fill_hash(.xor, 0xc0e04010, 1) == '42efa290100adaad'
	assert composite_fill_hash(.src, 0x80a0b0c0, 0.5) == '6df25b2f07108492'
	assert composite_fill_hash(.dst_atop, 0xffffffff, 1) == '4fa1c830de3ae55d'
	assert composite_fill_hash(.plus, 0xff000000, 0.6) == 'ef007e385399399e'
	assert composite_fill_hash(.hard_light, 0xe0ff4080, 0.9) == 'ec912c0a23af2b41'
}

fn test_highp_composite_fills_match_skia() {
	assert composite_fill_hash(.color_dodge, 0xd93e8017, 0.999) == 'f272fc341c2619b9'
	assert composite_fill_hash(.color_burn, 0xff40a0e0, 0.75) == '0d0dc5fa0a506c09'
	assert composite_fill_hash(.soft_light, 0xff80ff20, 0.7) == 'b650893eb6287170'
	assert composite_fill_hash(.hue, 0xff2060e0, 1) == '5ea53ddba5413894'
	assert composite_fill_hash(.luminosity, 0xa0808080, 1) == 'af6a9fc1042a7443'
}

fn test_composite_strokes_match_skia() {
	// A partial-coverage hairline carries its coverage in alpha for
	// destination-out, but source-in keeps the thin stroke as an outline.
	assert composite_stroke_hash(.dst_out, 0xff102030, 0.9, 0.6, [], []) == '85da63779395f1ed'
	assert composite_stroke_hash(.src_in, 0xff60a0f0, 0.9, 0.6, [], []) == '9480538143b7cb51'
	assert composite_stroke_hash(.color_burn, 0xffe08040, 1, 3, [f32(5), 2], []) == '301ac22f65b73cb0'
	mut circle := []f32{}
	circle << composite_test_segment(0, [f32(40), 20])
	circle << [f32(4), 8, 20, 0, 0, 0, 0, 16, 16, 0, 0, 1]
	circle << [f32(4), 40, 20, 0, 0, 0, 0, 16, 16, 0, 0, 1]
	circle << composite_test_segment(5, [])
	assert composite_stroke_hash(.saturation, 0xff20e060, 0.8, 5, [], [
		canvas_path(circle, false),
	]) == '19b71184289724e7'
}
