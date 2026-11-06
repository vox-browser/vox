module cpuraster

// SkBlitter_ARGB32.cpp (google/skia ee20d565): the legacy solid-color
// blitters LibWeb's Skia selects for src-over draws into premultiplied
// RGBA_8888, its kN32 color type on macOS. Packed pixels are SkPMColor:
// R in bits 0..7, G 8..15, B 16..23 and A 24..31.

@[inline]
fn load32(pixels []u8, offset int) u32 {
	return u32(pixels[offset]) | (u32(pixels[offset + 1]) << 8) | (u32(pixels[offset + 2]) << 16) | (u32(pixels[offset + 3]) << 24)
}

@[inline]
fn store32(mut pixels []u8, offset int, value u32) {
	pixels[offset] = u8(value)
	pixels[offset + 1] = u8(value >> 8)
	pixels[offset + 2] = u8(value >> 16)
	pixels[offset + 3] = u8(value >> 24)
}

// SkAlphaMulQ().
@[inline]
fn alpha_mul_q(c u32, scale u32) u32 {
	mask := u32(0x00ff00ff)
	rb := ((c & mask) * scale) >> 8
	ag := ((c >> 8) & mask) * scale
	return (rb & mask) | (ag & ~mask)
}

// SkMulDiv255Round().
@[inline]
fn mul_div255_round(a u32, b u32) u32 {
	prod := a * b + 128
	return (prod + (prod >> 8)) >> 8
}

// SkPreMultiplyColor() of an SkColor (0xAARRGGBB).
pub fn premultiply_color(color u32) u32 {
	a := color >> 24
	mut r := (color >> 16) & 0xff
	mut g := (color >> 8) & 0xff
	mut b := color & 0xff
	if a != 255 {
		r = mul_div255_round(r, a)
		g = mul_div255_round(g, a)
		b = mul_div255_round(b, a)
	}
	return (a << 24) | r | (g << 8) | (b << 16)
}

// SkAlphaMulInv256().
@[inline]
fn alpha_mul_inv256(value u32, alpha256 u32) u32 {
	prod := u32(0xffff) - value * alpha256
	return (prod + (prod >> 8)) >> 8
}

// SkBlendARGB32().
fn blend_argb32(src u32, dst u32, aa u32) u32 {
	src_scale := aa + 1
	dst_scale := alpha_mul_inv256(src >> 24, src_scale)
	mask := u32(0x00ff00ff)
	src_rb := (src & mask) * src_scale
	src_ag := ((src >> 8) & mask) * src_scale
	dst_rb := (dst & mask) * dst_scale
	dst_ag := ((dst >> 8) & mask) * dst_scale
	return (((src_rb + dst_rb) >> 8) & mask) | ((src_ag + dst_ag) & ~mask)
}

// SkSplay(color) to 0x00AA00GG00RR00BB.
@[inline]
fn splay(color u32) u64 {
	mask := u32(0x00ff00ff)
	mut agrb := u64((color >> 8) & mask)
	agrb <<= 32
	agrb |= u64(color & mask)
	return agrb
}

@[inline]
fn unsplay(agrb u64) u32 {
	mask := u64(0xff00ff00)
	return u32(((agrb & mask) >> 8) | ((agrb >> 32) & mask))
}

// SkFastFourByteInterp().
fn fast_four_byte_interp(src u32, dst u32, weight u32) u32 {
	scale := u64(weight + (weight >> 7))
	return unsplay(splay(src) * scale + (256 - scale) * splay(dst))
}

// SkOpts::blit_row_color32(): per byte, ((dst * (256 - a)) >> 8) + color.
fn blit_row_color32(mut pixels []u8, offset int, count int, color u32) {
	inv_a := 256 - (color >> 24)
	for i in 0 .. count {
		o := offset + i * 4
		for c in 0 .. 4 {
			s := u32(pixels[o + c])
			channel := (color >> (8 * c)) & 0xff
			pixels[o + c] = u8(((s * inv_a) >> 8) + channel)
		}
	}
}

// SkBlitRow::Color32().
fn color32(mut pixels []u8, offset int, count int, color u32) {
	match color >> 24 {
		0 {}
		255 {
			for i in 0 .. count {
				store32(mut pixels, offset + i * 4, color)
			}
		}
		else {
			blit_row_color32(mut pixels, offset, count, color)
		}
	}
}

enum SolidKind {
	general
	opaque
	black
}

// SkARGB32_Blitter, SkARGB32_Opaque_Blitter and SkARGB32_Black_Blitter.
pub struct SolidBlitter {
	kind      SolidKind
	color     u32
	pm_color  u32
	src_a     u32
	row_bytes int
mut:
	pixels []u8
}

// new_solid_blitter selects the blitter SkBlitter::Choose() does for an
// SkColor (0xAARRGGBB) on premultiplied RGBA_8888 pixels.
pub fn new_solid_blitter(mut pixels []u8, row_bytes int, color u32) SolidBlitter {
	kind := if color == 0xff000000 {
		SolidKind.black
	} else if color >> 24 == 255 {
		SolidKind.opaque
	} else {
		SolidKind.general
	}
	return SolidBlitter{
		kind:      kind
		color:     color
		pm_color:  premultiply_color(color)
		src_a:     color >> 24
		row_bytes: row_bytes
		pixels:    pixels
	}
}

@[inline]
fn (b &SolidBlitter) offset(x int, y int) int {
	return y * b.row_bytes + x * 4
}

fn (mut b SolidBlitter) blit_h(x int, y int, width int) {
	color32(mut b.pixels, b.offset(x, y), width, b.pm_color)
}

fn (mut b SolidBlitter) blit_anti_h(x int, y int, mut aa []u8, mut runs []i16) {
	if b.kind == .general && b.src_a == 0 {
		return
	}
	mut offset := b.offset(x, y)
	mut i := 0
	for {
		count := int(runs[i])
		if count <= 0 {
			return
		}
		alpha := u32(aa[i])
		match b.kind {
			.general {
				if alpha != 0 {
					color32(mut b.pixels, offset, count, alpha_mul_q(b.pm_color, alpha + 1))
				}
			}
			.opaque {
				if alpha == 255 {
					for k in 0 .. count {
						store32(mut b.pixels, offset + k * 4, b.pm_color)
					}
				} else if alpha > 0 {
					color32(mut b.pixels, offset, count, alpha_mul_q(b.pm_color, alpha + 1))
				}
			}
			.black {
				if alpha == 255 {
					for k in 0 .. count {
						store32(mut b.pixels, offset + k * 4, 0xff000000)
					}
				} else if alpha != 0 {
					src := alpha << 24
					dst_scale := 256 - alpha
					for k in 0 .. count {
						o := offset + k * 4
						store32(mut b.pixels, o, src + alpha_mul_q(load32(b.pixels, o), dst_scale))
					}
				}
			}
		}
		i += count
		offset += count * 4
	}
}

fn (mut b SolidBlitter) blend_one(offset int, alpha u32) {
	d := load32(b.pixels, offset)
	value := match b.kind {
		.general { blend_argb32(b.pm_color, d, alpha) }
		.opaque { fast_four_byte_interp(b.pm_color, d, alpha) }
		.black { (alpha << 24) + alpha_mul_q(d, 256 - alpha) }
	}
	store32(mut b.pixels, offset, value)
}

fn (mut b SolidBlitter) blit_anti_h2(x int, y int, a0 u8, a1 u8) {
	o := b.offset(x, y)
	b.blend_one(o, a0)
	b.blend_one(o + 4, a1)
}

fn (mut b SolidBlitter) blit_anti_v2(x int, y int, a0 u8, a1 u8) {
	o := b.offset(x, y)
	b.blend_one(o, a0)
	b.blend_one(o + b.row_bytes, a1)
}

fn (mut b SolidBlitter) blit_v(x int, y int, height int, alpha u8) {
	if alpha == 0 || b.src_a == 0 {
		return
	}
	mut color := b.pm_color
	if alpha != 255 {
		color = alpha_mul_q(color, u32(alpha) + 1)
	}
	dst_scale := 256 - (color >> 24)
	mut offset := b.offset(x, y)
	for _ in 0 .. height {
		store32(mut b.pixels, offset, color + alpha_mul_q(load32(b.pixels, offset), dst_scale))
		offset += b.row_bytes
	}
}

fn (mut b SolidBlitter) blit_rect(x int, y int, width int, height int) {
	if b.src_a == 0 {
		return
	}
	for row in 0 .. height {
		color32(mut b.pixels, b.offset(x, y + row), width, b.pm_color)
	}
}

fn (mut b SolidBlitter) blit_anti_rect(x int, y int, width int, height int, left_alpha u8, right_alpha u8) {
	default_blit_anti_rect(mut b, x, y, width, height, left_alpha, right_alpha)
}

// blit_color(): SkOpts::blit_mask_d32_a8() for an A8 mask.
fn (mut b SolidBlitter) blit_mask(mask &Mask, clip IRect) {
	if b.kind == .general && b.src_a == 0 {
		return
	}
	pmc := b.pm_color
	color_alpha := pmc >> 24
	for row in 0 .. clip.height() {
		mut dst := b.offset(clip.left, clip.top + row)
		mut src := mask.index(clip.left, clip.top + row)
		for _ in 0 .. clip.width() {
			m := u32(mask.image[src])
			d := load32(b.pixels, dst)
			value := if b.color == 0xff000000 {
				alpha_mul_q(d, 256 - m) + (m << 24)
			} else {
				m256 := m + 1
				scale := if b.color >> 24 == 255 {
					256 - m
				} else {
					256 - ((color_alpha * m256) >> 8)
				}
				alpha_mul_q(pmc, m256) + alpha_mul_q(d, scale)
			}
			store32(mut b.pixels, dst, value)
			dst += 4
			src++
		}
	}
}
