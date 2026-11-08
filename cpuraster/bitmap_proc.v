module cpuraster

import math

// The legacy bitmap shader context (google/skia ee20d565, NEON):
// SkImageShader::onMakeContext() accepts a premultiplied sRGB image whose
// two tile modes are equal and not decal for a source-over paint, and
// SkBlitter::Choose() then draws with SkARGB32_Shader_Blitter instead of the
// raster pipeline. SkBitmapProcState::init() and chooseProcs() pick the
// shader, matrix and sample procs (SkBitmapProcState.cpp,
// SkBitmapProcState_matrixProcs.cpp and SkBitmapProcState_opts.h), which
// sample in 32.32 and 16.16 fixed point with 4-bit bilinear weights; the
// blitter blends their spans with SkBlitRow's NEON procs.

// SkFloatToFixed3232(): sk_float_saturate2int64(v * 2^32).
fn float_to_fixed3232(v f32) i64 {
	scaled := v * f32(4294967296.0)
	if scaled != scaled {
		return max_s64_fits_in_float
	}
	limit := f32(max_s64_fits_in_float)
	clamped := if scaled < limit { scaled } else { limit }
	pinned := if clamped > -limit { clamped } else { -limit }
	return i64(pinned)
}

// SK_MaxS64FitsInFloat.
const max_s64_fits_in_float = i64(0x7fffff8000000000)

@[inline]
fn fixed3232_to_int(v i64) int {
	return int(i32(v >> 32))
}

@[inline]
fn fixed3232_to_fixed(v i64) i32 {
	return i32(v >> 16)
}

@[inline]
fn fixed_to_fixed3232(v i32) i64 {
	return i64(u64(i64(v)) << 16)
}

enum ShaderProc32 {
	none
	clamp_opaque_nofilter_dx
	constant_x
	clamp_trans
	repeat_trans
	do_nothing
}

// SkBitmapProcState once init() and chooseProcs() have run.
struct BitmapProcState {
	pixels    []u8
	width     int
	height    int
	row_bytes int
	// fInvMatrix, after the tiling and near-translate adjustments.
	m           SkAffine
	tile        TileMode
	bilerp      bool
	alpha_scale u32
	inv_sx      i64
	inv_ky      i64
mut:
	shader_proc  ShaderProc32
	filter_one_x i32
	filter_one_y i32
}

// legacy_shader_can_handle(): the device range's image-space bounds stay
// inside a quarter of the 32-bit fixed-point range.
fn legacy_shader_can_handle(inv SkAffine) bool {
	m := InverseMatrix{inv, inv.type_mask()}
	src := m.map_rect(Rect{0, 0, 32767, 32767})
	limit := f32(max_i32) * f32(0.25)
	if !(src.left < src.right && src.top < src.bottom) {
		return false
	}
	return -limit <= src.left && -limit <= src.top && limit >= src.right && limit >= src.bottom
}

// legacy_image_context is SkImageShader::onMakeContext() and
// SkBitmapProcLegacyShader::MakeContext() for image at paint alpha byte
// alpha, or none when the shader needs the raster pipeline.
fn legacy_image_context(image ImageShader, alpha int) ?BitmapProcState {
	if !image.native_n32 || image.premul || image.display_p3 || image.tile_x != image.tile_y || image.tile_x == .decal {
		return none
	}
	if image.width > 32767 || image.height > 32767 || !legacy_shader_can_handle(image.matrix) {
		return none
	}
	return new_bitmap_proc_state(image, alpha)
}

// matrix_only_scale_translate(): a scale and at most a translation.
fn only_scale_translate(m SkAffine) bool {
	return m.type_mask() & ~affine_translate_mask == affine_scale_mask
}

// just_trans_integral(): a translation within 1/256 of whole pixels.
fn just_trans_integral(m SkAffine) bool {
	tol := f32(1) / f32(256)
	return m.type_mask() <= affine_translate_mask
		&& nearly_equal(m.tx, floor_f32(m.tx + f32(0.5)), tol)
		&& nearly_equal(m.ty, floor_f32(m.ty + f32(0.5)), tol)
}

fn new_bitmap_proc_state(image ImageShader, alpha int) BitmapProcState {
	// The context keeps the shader's requested sampling: tweak_sampling() is
	// the raster pipeline's.
	mut m := image.matrix
	mut bilerp := image.linear
	mut integral := just_trans_integral(m)
	if !integral {
		// SkMatrixPriv::PostIDiv() into unit texture coordinates for repeat.
		if image.tile_x != .clamp {
			inv_x := f32(1) / f32(image.width)
			inv_y := f32(1) / f32(image.height)
			m = SkAffine{
				sx: m.sx * inv_x
				kx: m.kx * inv_x
				tx: m.tx * inv_x
				ky: m.ky * inv_y
				sy: m.sy * inv_y
				ty: m.ty * inv_y
			}
		}
		// A forward scale within 1/32768 of one is a translation.
		if only_scale_translate(m) {
			if forward := affine_invert(m) {
				tol := f32(1) / f32(32768)
				if nearly_zero(forward.sx - f32(1), tol) && nearly_zero(forward.sy - f32(1), tol) {
					m = SkAffine{
						tx: -forward.tx
						ty: -forward.ty
					}
				}
			}
		}
		integral = just_trans_integral(m)
	}
	if bilerp && ((image.width | image.height) & ~0x3fff != 0 || integral) {
		bilerp = false
	}
	mut s := BitmapProcState{
		pixels:      image.pixels
		width:       image.width
		height:      image.height
		row_bytes:   image.stride * 4
		m:           m
		tile:        image.tile_x
		bilerp:      bilerp
		alpha_scale: u32(alpha) + 1
		inv_sx:      float_to_fixed3232(m.sx)
		inv_ky:      float_to_fixed3232(m.ky)
	}
	// chooseMatrixProc(): the filter offsets for the scale and affine procs.
	if !(s.is_translate() && !bilerp) {
		if s.tile == .clamp {
			s.filter_one_x = 1 << 16
			s.filter_one_y = 1 << 16
		} else {
			s.filter_one_x = i32((1 << 16) / image.width)
			s.filter_one_y = i32((1 << 16) / image.height)
		}
	}
	s.shader_proc = s.choose_shader_proc()
	return s
}

@[inline]
fn (s &BitmapProcState) is_translate() bool {
	return s.m.type_mask() & ~affine_translate_mask == 0
}

@[inline]
fn (s &BitmapProcState) is_scale_translate() bool {
	return s.m.type_mask() & affine_affine_mask == 0
}

// chooseProcs()'s special case, then chooseShaderProc32().
fn (mut s BitmapProcState) choose_shader_proc() ShaderProc32 {
	if s.alpha_scale == 256 && !s.bilerp && s.tile == .clamp && s.is_scale_translate() {
		return .clamp_opaque_nofilter_dx
	}
	if s.width == 1 && s.is_scale_translate() {
		if !s.bilerp && s.is_translate() && !s.setup_for_translate() {
			return .do_nothing
		}
		return .constant_x
	}
	if s.alpha_scale < 256 || !s.is_translate() || s.bilerp {
		return .none
	}
	if s.setup_for_translate() {
		return if s.tile == .clamp { ShaderProc32.clamp_trans } else { .repeat_trans }
	}
	return .do_nothing
}

// SkBitmapProcStateAutoMapper: the pixel center through the inverse matrix
// (mapPointAffine()), less the bilerp half step or one 16.16 unit.
fn (s &BitmapProcState) map(x int, y int) (i64, i64, Point) {
	px := f32(x) + f32(0.5)
	py := f32(y) + f32(0.5)
	xx := px * s.m.sx
	xy := py * s.m.kx
	yx := px * s.m.ky
	yy := py * s.m.sy
	sum_x := xx + xy
	sum_y := yx + yy
	pt := Point{sum_x + s.m.tx, sum_y + s.m.ty}
	bias_x := if s.bilerp { s.filter_one_x >> 1 } else { i32(1) }
	bias_y := if s.bilerp { s.filter_one_y >> 1 } else { i32(1) }
	fx := i64(u64(float_to_fixed3232(pt.x)) - u64(fixed_to_fixed3232(bias_x)))
	fy := i64(u64(float_to_fixed3232(pt.y)) - u64(fixed_to_fixed3232(bias_y)))
	// SkFixedToScalar(): bias * 1/65536.
	scalar_bias_x := f32(bias_x) * f32(1.52587890625e-05)
	scalar_bias_y := f32(bias_y) * f32(1.52587890625e-05)
	return fx, fy, Point{pt.x - scalar_bias_x, pt.y - scalar_bias_y}
}

// setupForTranslate(): the integer offset from device to image pixels.
fn (mut s BitmapProcState) setup_for_translate() bool {
	fx, fy, pt := s.map(0, 0)
	too_big := f32(1 << 30)
	if f32(math.abs(pt.x)) > too_big || f32(math.abs(pt.y)) > too_big {
		return false
	}
	s.filter_one_x = i32(fixed3232_to_int(fx))
	s.filter_one_y = i32(fixed3232_to_int(fy))
	return true
}

@[inline]
fn (s &BitmapProcState) pixel(x int, y int) u32 {
	return load32(s.pixels, y * s.row_bytes + x * 4)
}

// sk_int_mod(): 0 .. n - 1 for any x.
fn sk_int_mod(x int, n int) int {
	if u32(x) >= u32(n) {
		if x < 0 {
			return n + ~(~x % n)
		}
		return x % n
	}
	return x
}

@[inline]
fn pin_int(v int, lo int, hi int) int {
	return if v < lo {
		lo
	} else if v > hi {
		hi
	} else {
		v
	}
}

// The 16.16 tile procs: clamp() and repeat().
fn (s &BitmapProcState) tile_fixed(f i32, max int) u32 {
	if s.tile == .clamp {
		return u32(pin_int(int(f >> 16), 0, max))
	}
	return ((u32(f) & 0xffff) * u32(max + 1)) >> 16
}

// extract_low_bits_clamp_clamp() and extract_low_bits_general().
fn (s &BitmapProcState) low_bits(f i32, max int) u32 {
	if s.tile == .clamp {
		return u32((f >> 12) & 0xf)
	}
	scaled := i32(int(f & 0xffff) * (max + 1))
	return u32((scaled >> 12) & 0xf)
}

// pack(): low coordinate, 4-bit weight and high coordinate.
fn (s &BitmapProcState) pack(f i32, max int, one i32) u32 {
	mut packed := s.tile_fixed(f, max)
	packed = (packed << 4) | s.low_bits(f, max)
	return (packed << 14) | s.tile_fixed(i32(u32(f) + u32(one)), max)
}

// sk_fixed3232_saturate2fixed().
fn saturate_to_fixed(v i64) i32 {
	mut x := v
	x = if (x >> 32) < 32767 { x } else { i64(32767) << 32 }
	x = if (x >> 32) > -32768 { x } else { i64(-32768) << 32 }
	return fixed3232_to_fixed(x)
}

// decode_packed_coordinates_and_weight().
@[inline]
fn unpack_filter(packed u32) (int, int, u32) {
	return int(packed >> 18), int(packed & 0x3fff), (packed >> 14) & 0xf
}

// filter_and_scale_by_alpha() on NEON: per byte, the four weights as 16-bit
// products, then the alpha scale.
fn filter_and_scale_by_alpha(x u32, y u32, a00 u32, a01 u32, a10 u32, a11 u32, scale u32) u32 {
	mut out := u32(0)
	for c in 0 .. 4 {
		shift := u32(8 * c)
		p00 := (a00 >> shift) & 0xff
		p01 := (a01 >> shift) & 0xff
		p10 := (a10 >> shift) & 0xff
		p11 := (a11 >> shift) & 0xff
		mut t := (p01 * (16 - y)) * x
		t = (t + (p11 * y) * x) & 0xffff
		t = (t + (p00 * (16 - y)) * (16 - x)) & 0xffff
		t = (t + (p10 * y) * (16 - x)) & 0xffff
		if scale < 256 {
			t = ((t >> 8) * scale) & 0xffff
		}
		out |= ((t >> 8) & 0xff) << shift
	}
	return out
}

// filter_32_alpha() for the one-pixel-wide shader proc.
fn filter_32_alpha(t u32, color0 u32, color1 u32, alpha_scale u32) u32 {
	mask := u32(0xff00ff)
	mut scale := 256 - 16 * t
	mut lo := (color0 & mask) * scale
	mut hi := ((color0 >> 8) & mask) * scale
	scale = 16 * t
	lo += (color1 & mask) * scale
	hi += ((color1 >> 8) & mask) * scale
	lo = ((lo >> 8) & mask) * alpha_scale
	hi = ((hi >> 8) & mask) * alpha_scale
	return ((lo >> 8) & mask) | (hi & ~mask)
}

// shade_span is BitmapProcShaderContext::shadeSpan(): the shader proc, or
// the matrix and sample procs over chunks maxCountForBufferSize() allows
// for its 128-entry buffer.
fn (s &BitmapProcState) shade_span(x int, y int, mut colors []u32, count int) {
	match s.shader_proc {
		.clamp_opaque_nofilter_dx {
			s.clamp_opaque_nofilter(x, y, mut colors, count)
			return
		}
		.constant_x {
			s.constant_x(x, y, mut colors, count)
			return
		}
		.clamp_trans, .repeat_trans {
			s.trans_shader(x, y, mut colors, count)
			return
		}
		.do_nothing {
			for i in 0 .. count {
				colors[i] = 0
			}
			return
		}
		.none {}
	}
	mut max := 128
	if s.is_scale_translate() {
		max = 254
	}
	if s.bilerp {
		max >>= 1
	}
	mut done := 0
	for done < count {
		n := if count - done < max { count - done } else { max }
		s.sample_chunk(x + done, y, mut colors, done, n)
		done += n
	}
}

// Clamp_S32_opaque_D32_nofilter_DX_shaderproc.
fn (s &BitmapProcState) clamp_opaque_nofilter(x int, y int, mut colors []u32, count int) {
	max_x := s.width - 1
	mut fx, fy, _ := s.map(x, y)
	dst_y := pin_int(fixed3232_to_int(fy), 0, s.height - 1)
	for i in 0 .. count {
		colors[i] = s.pixel(pin_int(fixed3232_to_int(fx), 0, max_x), dst_y)
		fx += s.inv_sx
	}
}

// S32_D32_constX_shaderproc: one column, so one color per span.
fn (s &BitmapProcState) constant_x(x int, y int, mut colors []u32, count int) {
	mut color := u32(0)
	if s.bilerp {
		_, fy, _ := s.map(x, y)
		packed := s.pack(saturate_to_fixed(fy), s.height - 1, s.filter_one_y)
		y0, y1, sub_y := unpack_filter(packed)
		color = filter_32_alpha(sub_y, s.pixel(0, y0), s.pixel(0, y1), s.alpha_scale)
	} else {
		mut y_temp := 0
		if s.is_translate() {
			y_temp = int(s.filter_one_y) + y
		} else {
			_, fy, _ := s.map(x, y)
			y_temp = if s.tile != .clamp {
				fixed3232_to_int(i64(u64(fy) * u64(s.height)))
			} else {
				fixed3232_to_int(fy)
			}
		}
		y0 := if s.tile == .clamp {
			pin_int(y_temp, 0, s.height - 1)
		} else {
			sk_int_mod(y_temp, s.height)
		}
		color = s.pixel(0, y0)
		if s.alpha_scale < 256 {
			color = alpha_mul_q(color, s.alpha_scale)
		}
	}
	for i in 0 .. count {
		colors[i] = color
	}
}

// Clamp_ and Repeat_S32_D32_nofilter_trans_shaderproc.
fn (s &BitmapProcState) trans_shader(x int, y int, mut colors []u32, count int) {
	ix := int(s.filter_one_x) + x
	iy0 := int(s.filter_one_y) + y
	if s.shader_proc == .clamp_trans {
		iy := pin_int(iy0, 0, s.height - 1)
		for i in 0 .. count {
			colors[i] = s.pixel(pin_int(ix + i, 0, s.width - 1), iy)
		}
		return
	}
	iy := sk_int_mod(iy0, s.height)
	mut col := sk_int_mod(ix, s.width)
	for i in 0 .. count {
		colors[i] = s.pixel(col, iy)
		col++
		if col == s.width {
			col = 0
		}
	}
}

// The matrix proc and sample proc for n pixels from (x, y), written to
// colors[at..].
fn (s &BitmapProcState) sample_chunk(x int, y int, mut colors []u32, at int, n int) {
	max_x := s.width - 1
	max_y := s.height - 1
	if s.is_translate() && !s.bilerp {
		// clampx_nofilter_trans / repeatx_nofilter_trans, then
		// S32_alpha_D32_nofilter_DX.
		fx, fy, _ := s.map(x, y)
		iy := fixed3232_to_int(fy)
		row := if s.tile == .clamp { pin_int(iy, 0, max_y) } else { sk_int_mod(iy, s.height) }
		xpos := fixed3232_to_int(fx)
		for i in 0 .. n {
			col := if s.width == 1 {
				0
			} else if s.tile == .clamp {
				pin_int(xpos + i, 0, max_x)
			} else {
				sk_int_mod(xpos + i, s.width)
			}
			colors[at + i] = alpha_mul_q(s.pixel(col, row), s.alpha_scale)
		}
		return
	}
	if s.is_scale_translate() {
		if s.bilerp {
			s.filter_scale(x, y, mut colors, at, n)
		} else {
			s.nofilter_scale(x, y, mut colors, at, n)
		}
		return
	}
	mut fx, mut fy, _ := s.map(x, y)
	for i in 0 .. n {
		if s.bilerp {
			// filter_affine, then S32_alpha_D32_filter_DXDY.
			yp := s.pack(fixed3232_to_fixed(fy), max_y, s.filter_one_y)
			xp := s.pack(fixed3232_to_fixed(fx), max_x, s.filter_one_x)
			y0, y1, wy := unpack_filter(yp)
			x0, x1, wx := unpack_filter(xp)
			colors[at + i] = filter_and_scale_by_alpha(wx, wy, s.pixel(x0, y0), s.pixel(x1, y0),
				s.pixel(x0, y1), s.pixel(x1, y1), s.alpha_scale)
		} else {
			// nofilter_affine, then S32_alpha_D32_nofilter_DXDY.
			row := s.tile_fixed(fixed3232_to_fixed(fy), max_y)
			col := s.tile_fixed(fixed3232_to_fixed(fx), max_x)
			packed := (row << 16) | col
			colors[at + i] = alpha_mul_q(s.pixel(int(packed & 0xffff), int(packed >> 16)), s.alpha_scale)
		}
		fy += s.inv_ky
		fx += s.inv_sx
	}
}

// can_truncate_to_fixed_for_decal().
fn can_truncate_to_fixed_for_decal(fx i32, dx i32, count int, max int) bool {
	if dx <= (1 << 16) / 256 {
		return false
	}
	if u32(fx >> 16) >= u32(max) {
		return false
	}
	last := u64(i64(fx)) + u64(i64(dx) * i64(count - 1))
	last_signed := i64(last)
	if last_signed < min_i32 || last_signed > max_i32 {
		return false
	}
	return u32(i32(last_signed) >> 16) < u32(max)
}

// nofilter_scale (with clamp's decal_nofilter_scale fast path), then
// S32_alpha_D32_nofilter_DX.
fn (s &BitmapProcState) nofilter_scale(x int, y int, mut colors []u32, at int, n int) {
	max_x := s.width - 1
	mut fx, fy, _ := s.map(x, y)
	row := int(s.tile_fixed(fixed3232_to_fixed(fy), s.height - 1))
	mut xs := []u16{len: n}
	if max_x != 0 {
		dx := s.inv_sx
		mut decal := false
		if s.tile == .clamp {
			fixed_fx := fixed3232_to_fixed(fx)
			fixed_dx := fixed3232_to_fixed(dx)
			if can_truncate_to_fixed_for_decal(fixed_fx, fixed_dx, n, max_x) {
				decal = true
				mut f := fixed_fx
				mut i := 0
				mut left := n
				for ; left > 2; left -= 2 {
					xs[i] = u16(f >> 16)
					xs[i + 1] = u16(i32(u32(f) + u32(fixed_dx)) >> 16)
					i += 2
					f = i32(u32(f) + u32(fixed_dx) + u32(fixed_dx))
				}
				if left == 2 {
					xs[i + 1] = u16(i32(u32(f) + u32(fixed_dx)) >> 16)
				}
				if left >= 1 {
					xs[i] = u16(f >> 16)
				}
			}
		}
		if !decal {
			for i in 0 .. n {
				xs[i] = u16(s.tile_fixed(fixed3232_to_fixed(fx), max_x))
				fx += dx
			}
		}
	}
	if s.width == 1 {
		color := alpha_mul_q(s.pixel(0, row), s.alpha_scale)
		for i in 0 .. n {
			colors[at + i] = color
		}
		return
	}
	for i in 0 .. n {
		colors[at + i] = alpha_mul_q(s.pixel(int(xs[i]), row), s.alpha_scale)
	}
}

// filter_scale (with clamp's decal fast path), then S32_alpha_D32_filter_DX.
fn (s &BitmapProcState) filter_scale(x int, y int, mut colors []u32, at int, n int) {
	max_x := s.width - 1
	dx := s.inv_sx
	mut fx, fy, _ := s.map(x, y)
	y0, y1, wy := unpack_filter(s.pack(saturate_to_fixed(fy), s.height - 1, s.filter_one_y))
	decal := s.tile == .clamp && u32(fixed3232_to_int(fx)) < u32(max_x)
		&& u32(fixed3232_to_int(i64(u64(fx) + u64(dx * i64(n - 1))))) < u32(max_x)
	for i in 0 .. n {
		packed := if decal {
			fixed_fx := saturate_to_fixed(fx)
			(u32(fixed_fx >> 12) << 14) | u32((fixed_fx >> 16) + 1)
		} else {
			s.pack(saturate_to_fixed(fx), max_x, s.filter_one_x)
		}
		fx += dx
		x0, x1, wx := unpack_filter(packed)
		colors[at + i] = filter_and_scale_by_alpha(wx, wy, s.pixel(x0, y0), s.pixel(x1, y0),
			s.pixel(x0, y1), s.pixel(x1, y1), s.alpha_scale)
	}
}

// SkARGB32_Shader_Blitter for a shader context without kOpaqueAlpha_Flag:
// spans blend with SkOpts::blit_row_s32a_opaque, or blit_row_s32a_blend
// under partial coverage.
pub struct LegacyShaderBlitter {
	state     BitmapProcState
	row_bytes int
mut:
	pixels []u8
	span   []u32
}

fn new_legacy_shader_blitter(mut pixels []u8, row_bytes int, state BitmapProcState) LegacyShaderBlitter {
	return LegacyShaderBlitter{
		state:     state
		row_bytes: row_bytes
		pixels:    pixels
		span:      []u32{len: row_bytes / 4 + 1}
	}
}

// SkBlitRow::Factory32(kSrcPixelAlpha_Flag32) for full coverage and with
// kGlobalAlpha_Flag32 for partial coverage alpha: blends count premultiplied
// span colors into pixels from offset.
fn blit_row_s32a(mut pixels []u8, offset int, span []u32, count int, alpha u32) {
	if alpha == 255 {
		blit_row_s32a_opaque(mut pixels, offset, span, count)
	} else {
		blit_row_s32a_blend(mut pixels, offset, span, count, alpha)
	}
}

// SkPMSrcOver_neon: per byte, src + SkMulDiv255Round(255 - src alpha, dst)
// saturated.
fn blit_row_s32a_opaque(mut pixels []u8, offset int, span []u32, count int) {
	for i in 0 .. count {
		o := offset + i * 4
		s := span[i]
		inv_a := 255 - (s >> 24)
		for c in 0 .. 4 {
			sc := (s >> (8 * u32(c))) & 0xff
			v := sc + mul_div255_round(inv_a, u32(pixels[o + c]))
			pixels[o + c] = u8(if v > 255 { u32(255) } else { v })
		}
	}
}

// blit_row_s32a_blend() on NEON: an odd first pixel with the exact
// SkAlphaMulInv256(), then pairs with its 16-bit approximation.
fn blit_row_s32a_blend(mut pixels []u8, offset int, span []u32, count int, alpha u32) {
	alpha256 := alpha + 1
	mut i := 0
	if count & 1 != 0 {
		blend_scaled_pixel(mut pixels, offset, span[0], alpha256, alpha_mul_inv256(span[0] >> 24,
			alpha256))
		i = 1
	}
	for ; i < count; i++ {
		sa := span[i] >> 24
		mut scale := (u32(0xff00) - sa * alpha256) & 0xffff
		scale = (scale + (scale >> 8)) & 0xffff
		scale = (1 + (scale >> 8)) & 0xffff
		blend_scaled_pixel(mut pixels, offset + i * 4, span[i], alpha256, scale)
	}
}

@[inline]
fn blend_scaled_pixel(mut pixels []u8, o int, s u32, src_scale u32, dst_scale u32) {
	for c in 0 .. 4 {
		sc := ((s >> (8 * u32(c))) & 0xff) * src_scale
		dc := u32(pixels[o + c]) * dst_scale
		pixels[o + c] = u8(((sc + dc) & 0xffff) >> 8)
	}
}

fn (mut b LegacyShaderBlitter) shade(x int, y int, count int) {
	if b.span.len < count {
		b.span = []u32{len: count}
	}
	b.state.shade_span(x, y, mut b.span, count)
}

fn (mut b LegacyShaderBlitter) blit_h(x int, y int, width int) {
	b.shade(x, y, width)
	blit_row_s32a(mut b.pixels, y * b.row_bytes + x * 4, b.span, width, 255)
}

fn (mut b LegacyShaderBlitter) blit_rect(x int, y int, width int, height int) {
	for row in 0 .. height {
		b.blit_h(x, y + row, width)
	}
}

fn (mut b LegacyShaderBlitter) blit_anti_h(x_in int, y int, mut aa []u8, mut runs []i16) {
	mut x := x_in
	mut i := 0
	for {
		count := int(runs[i])
		if count <= 0 {
			break
		}
		a := aa[i]
		if a != 0 {
			b.shade(x, y, count)
			blit_row_s32a(mut b.pixels, y * b.row_bytes + x * 4, b.span, count, u32(a))
		}
		i += count
		x += count
	}
}

fn (mut b LegacyShaderBlitter) blit_v(x int, y int, height int, alpha u8) {
	for row in 0 .. height {
		b.shade(x, y + row, 1)
		blit_row_s32a(mut b.pixels, (y + row) * b.row_bytes + x * 4, b.span, 1, u32(alpha))
	}
}

fn (mut b LegacyShaderBlitter) blit_anti_rect(x int, y int, width int, height int, left_alpha u8, right_alpha u8) {
	default_blit_anti_rect(mut b, x, y, width, height, left_alpha, right_alpha)
}

fn (mut b LegacyShaderBlitter) blit_anti_h2(x int, y int, a0 u8, a1 u8) {
	default_blit_anti_h2(mut b, x, y, a0, a1)
}

fn (mut b LegacyShaderBlitter) blit_anti_v2(x int, y int, a0 u8, a1 u8) {
	default_blit_anti_v2(mut b, x, y, a0, a1)
}

// skvx::approx_scale(): (x * y + x) / 256.
@[inline]
fn approx_scale(x u32, y u32) u32 {
	return (x * y + x) >> 8
}

// blitMask() with blend_row_A8.
fn (mut b LegacyShaderBlitter) blit_mask(mask &Mask, clip IRect) {
	width := clip.width()
	for row in 0 .. clip.height() {
		y := clip.top + row
		b.shade(clip.left, y, width)
		o := y * b.row_bytes + clip.left * 4
		m := mask.index(clip.left, y)
		for i in 0 .. width {
			c := u32(mask.image[m + i])
			s := b.span[i]
			sa := approx_scale(s >> 24, c)
			for k in 0 .. 4 {
				s_aa := approx_scale((s >> (8 * u32(k))) & 0xff, c)
				d := u32(b.pixels[o + i * 4 + k])
				b.pixels[o + i * 4 + k] = u8(s_aa + approx_scale(d, 255 - sa))
			}
		}
	}
}
