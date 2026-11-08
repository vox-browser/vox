module cpuraster

import math

// The raster blur engine of image filters for RGBA_8888 images
// (SkBlurEngine.cpp's Raster8888BlurAlgorithm): separable horizontal and
// vertical passes over premultiplied pixels, a Gaussian kernel in floats
// below sigma 2 and three integer box blurs approximating it up to the
// algorithm's maximum sigma of 135. Images outside their bounds are
// transparent (decal).

// Raster8888BlurAlgorithm::maxSigma().
const image_blur_max_sigma = f32(135)

// SkBlurEngine::IsEffectivelyIdentity().
fn blur_is_identity(sigma f32) bool {
	return sigma <= f32(0.03)
}

// SkBlurEngine::SigmaToRadius().
fn blur_sigma_to_radius(sigma f32) int {
	if blur_is_identity(sigma) {
		return 0
	}
	return float_saturate2int(ceil_f32(f32(3) * sigma))
}

// SkBlurEngine::BoxBlurWindow().
fn box_blur_window(sigma f32) int {
	pi := f32(3.14159265358979323846)
	root := C.sqrtf(f32(2) * pi)
	scaled := sigma * f32(3)
	product := scaled * root
	quarter := product / f32(4)
	window := float_saturate2int(floor_f32(quarter + f32(0.5)))
	return if window > 1 { window } else { 1 }
}

fn C.expf(x f32) f32

// BlurImage is an RGBA_8888 premultiplied bitmap, rows packed.
pub struct BlurImage {
pub mut:
	pixels []u8
	width  int
	height int
}

// A pass's per-pixel state; segment() mirrors Pass::blurSegment() with
// optional source and destination, as pixel indexes and strides into the
// images.
interface BlurPass {
	border int
mut:
	start()
	segment(n int, src []u8, src_index int, src_stride int, mut dst []u8, dst_index int, dst_stride int, has_src bool, has_dst bool)
}

// Pass::blur(): one row or column, with source pixels srcLeft..srcRight
// relative to the destination's start, writing dst_count pixels.
fn run_blur_pass(mut pass BlurPass, src_left int, src_right int, dst_count int, src []u8, src_start int, src_stride int, mut dst []u8, dst_start int, dst_stride int) {
	pass.start()
	src_start_idx := src_left - pass.border
	src_end := src_right - pass.border
	mut src_idx := src_start_idx
	mut dst_idx := 0
	mut src_cursor := src_start
	mut dst_cursor := dst_start
	if dst_idx < src_idx {
		common_end := if src_idx < dst_count { src_idx } else { dst_count }
		for dst_idx < common_end {
			store_pixel(mut dst, dst_cursor, 0)
			dst_cursor += dst_stride
			dst_idx++
		}
	} else if src_idx < dst_idx {
		common_end := if dst_idx < src_end { dst_idx } else { src_end }
		if src_idx < common_end {
			n := common_end - src_idx
			pass.segment(n, src, src_cursor, src_stride, mut dst, 0, 0, true, false)
			src_idx += n
			src_cursor += n * src_stride
		}
		if src_idx < dst_idx {
			n := dst_idx - src_idx
			pass.segment(n, src, 0, 0, mut dst, 0, 0, false, false)
			src_idx += n
		}
	}
	common := if dst_count < src_end { dst_count } else { src_end }
	if dst_idx < common {
		n := common - dst_idx
		pass.segment(n, src, src_cursor, src_stride, mut dst, dst_cursor, dst_stride, true, true)
		src_cursor += n * src_stride
		dst_cursor += n * dst_stride
		dst_idx += n
		src_idx += n
	}
	if dst_idx < dst_count {
		n := dst_count - dst_idx
		pass.segment(n, src, 0, 0, mut dst, dst_cursor, dst_stride, false, true)
	}
}

@[inline]
fn store_pixel(mut px []u8, index int, value u32) {
	o := index * 4
	px[o] = u8(value)
	px[o + 1] = u8(value >> 8)
	px[o + 2] = u8(value >> 16)
	px[o + 3] = u8(value >> 24)
}

// GaussianPass: a ring of the window's source pixels as floats, convolved
// with Compute1DBlurKernel()'s normalized kernel.
type BlurFloatPixel = [4]f32

type BlurUintPixel = [4]u32

struct GaussianBlurPass {
	border int
	window int
	kernel []f32
mut:
	ring []BlurFloatPixel
	base int
}

fn new_gaussian_blur_pass(sigma f32) GaussianBlurPass {
	radius := blur_sigma_to_radius(sigma)
	width := 2 * radius + 1
	return GaussianBlurPass{
		border: radius
		window: width
		kernel: blur_kernel_1d(sigma, radius)
		ring:   []BlurFloatPixel{len: width}
	}
}

// SkShaderBlurAlgorithm::Compute2DBlurKernel() for {sigma, 0}.
fn blur_kernel_1d(sigma f32, radius int) []f32 {
	width := 2 * radius + 1
	two := f32(2) * sigma
	two_sigma_sqrd := two * sigma
	denom := if radius > 0 { f32(1) / two_sigma_sqrd } else { f32(1) }
	mut kernel := []f32{len: width}
	mut sum := f32(0)
	for x in 0 .. width {
		mut term := f32(x - radius)
		squared := term * term
		term = squared * denom
		y_term := f32(0) * f32(0)
		value := C.expf(-(term + y_term))
		kernel[x] = value
		sum += value
	}
	scale := f32(1) / sum
	for i in 0 .. width {
		kernel[i] = kernel[i] * scale
	}
	return kernel
}

fn (mut p GaussianBlurPass) start() {
	for i in 0 .. p.ring.len {
		p.ring[i] = [f32(0), 0, 0, 0]!
	}
	p.base = 0
}

fn (mut p GaussianBlurPass) segment(n int, src []u8, src_index int, src_stride int, mut dst []u8, dst_index int, dst_stride int, has_src bool, has_dst bool) {
	mut base := p.base
	mut s := src_index
	mut d := dst_index
	for _ in 0 .. n {
		mut edge := [f32(0), 0, 0, 0]!
		if has_src {
			o := s * 4
			for c in 0 .. 4 {
				edge[c] = f32(src[o + c]) * (f32(1) / f32(255))
			}
		}
		p.ring[(base + p.window - 1) % p.window] = edge
		if has_dst {
			mut sum := [f32(0), 0, 0, 0]!
			for i in 0 .. p.window {
				v := p.ring[(i + base) % p.window]
				for c in 0 .. 4 {
					term := v[c] * p.kernel[i]
					sum[c] = sum[c] + term
				}
			}
			mut out := u32(0)
			for c in 0 .. 4 {
				scaled := sum[c] * f32(255)
				biased := scaled + f32(0.5)
				pinned := neon_max(f32(0), neon_min(biased, f32(255)))
				out |= u32(u8(pinned)) << (8 * c)
			}
			store_pixel(mut dst, d, out)
			d += dst_stride
		}
		if has_src {
			s += src_stride
		}
		base = (base + 1) % p.window
	}
	p.base = base
}

// skvx::ScaledDividerU32.
struct ScaledDividerU32 {
	factor u32
	half   u32
}

fn new_scaled_divider_u32(divisor u32) ScaledDividerU32 {
	scaled := (f64(1) / f64(divisor)) * f64(u64(1) << 32)
	return ScaledDividerU32{
		factor: u32(math.round(scaled))
		half:   (divisor + 1) >> 1
	}
}

@[inline]
fn (d ScaledDividerU32) divide(numerator u32) u32 {
	return u32((u64(numerator) * u64(d.factor)) >> 32)
}

// ThreeBoxApproxPass: three running box sums over windows of `window`
// pixels, offset to center an even window, divided by the window's cube.
struct ThreeBoxBlurPass {
	border  int
	divider ScaledDividerU32
	// The three ring buffers' starts and the end, in one buffer.
	b1  int
	b2  int
	end int
mut:
	buffer []BlurUintPixel
	sum0   BlurUintPixel
	sum1   BlurUintPixel
	sum2   BlurUintPixel
	c0     int
	c1     int
	c2     int
}

fn new_three_box_blur_pass(window int) ThreeBoxBlurPass {
	pass_size := window - 1
	odd := window & 1 == 1
	b1 := pass_size
	b2 := b1 + pass_size
	end := b2 + if odd { pass_size } else { pass_size + 1 }
	border := if odd { 3 * ((window - 1) / 2) } else { 3 * (window / 2) - 1 }
	window2 := window * window
	window3 := window2 * window
	divisor := if odd { window3 } else { window3 + window2 }
	return ThreeBoxBlurPass{
		border:  border
		divider: new_scaled_divider_u32(u32(divisor))
		b1:      b1
		b2:      b2
		end:     end
		buffer:  []BlurUintPixel{len: end}
	}
}

fn (mut p ThreeBoxBlurPass) start() {
	h := p.divider.half
	for c in 0 .. 4 {
		p.sum0[c] = 0
		p.sum1[c] = 0
		p.sum2[c] = h
	}
	for i in 0 .. p.buffer.len {
		p.buffer[i] = [u32(0), 0, 0, 0]!
	}
	p.c0 = 0
	p.c1 = p.b1
	p.c2 = p.b2
}

fn (mut p ThreeBoxBlurPass) segment(n int, src []u8, src_index int, src_stride int, mut dst []u8, dst_index int, dst_stride int, has_src bool, has_dst bool) {
	mut s := src_index
	mut d := dst_index
	for _ in 0 .. n {
		mut edge := [u32(0), 0, 0, 0]!
		if has_src {
			o := s * 4
			edge = [u32(src[o]), u32(src[o + 1]), u32(src[o + 2]), u32(src[o + 3])]!
		}
		mut out := u32(0)
		for c in 0 .. 4 {
			p.sum0[c] += edge[c]
			p.sum1[c] += p.sum0[c]
			p.sum2[c] += p.sum1[c]
			out |= u32(u8(p.divider.divide(p.sum2[c]))) << (8 * c)
			p.sum2[c] -= p.buffer[p.c2][c]
		}
		p.buffer[p.c2] = p.sum1
		p.c2 = if p.c2 + 1 < p.end { p.c2 + 1 } else { p.b2 }
		for c in 0 .. 4 {
			p.sum1[c] -= p.buffer[p.c1][c]
		}
		p.buffer[p.c1] = p.sum0
		p.c1 = if p.c1 + 1 < p.b2 { p.c1 + 1 } else { p.b1 }
		for c in 0 .. 4 {
			p.sum0[c] -= p.buffer[p.c0][c]
		}
		p.buffer[p.c0] = edge
		p.c0 = if p.c0 + 1 < p.b1 { p.c0 + 1 } else { 0 }
		if has_dst {
			store_pixel(mut dst, d, out)
			d += dst_stride
		}
		if has_src {
			s += src_stride
		}
	}
}

// Raster8888BlurAlgorithm's makeMaker(): a Gaussian pass below sigma 2,
// otherwise three boxes (every sigma up to 135 has a window below 255).
// The window is 1 (no pass) for an effectively zero sigma.
struct BlurMaker {
	window   int
	sigma    f32
	gaussian bool
}

fn new_blur_maker(sigma f32) BlurMaker {
	if sigma < f32(2) {
		return BlurMaker{2 * blur_sigma_to_radius(sigma) + 1, sigma, true}
	}
	return BlurMaker{box_blur_window(sigma), sigma, false}
}

fn (m BlurMaker) pass() BlurPass {
	if m.gaussian {
		return new_gaussian_blur_pass(m.sigma)
	}
	return new_three_box_blur_pass(m.window)
}

// eval_blur_passes(): src's pixels cover src_bounds; the result covers the
// destination bounds, possibly outset vertically for the horizontal pass,
// with dst_bounds' subset returned relative to the result's origin.
fn blur_8888(sigma_x f32, sigma_y f32, src BlurImage, src_bounds_in IRect, dst_bounds_in IRect) (BlurImage, IRect) {
	maker_x := new_blur_maker(sigma_x)
	maker_y := new_blur_maker(sigma_y)
	mut src_bounds := src_bounds_in
	mut dst_bounds := dst_bounds_in
	if maker_x.window > 1 {
		r := blur_sigma_to_radius(maker_y.sigma)
		dst_bounds = IRect{dst_bounds.left, dst_bounds.top - r, dst_bounds.right, dst_bounds.bottom + r}
	}
	dst_origin_x := dst_bounds.left
	dst_origin_y := dst_bounds.top
	mut dst := BlurImage{
		pixels: []u8{len: dst_bounds.width() * dst_bounds.height() * 4}
		width:  dst_bounds.width()
		height: dst_bounds.height()
	}
	mut loop_start := math.max(src_bounds.left, dst_bounds.left)
	mut loop_end := math.min(src_bounds.right, dst_bounds.right)
	mut dst_y_offset := 0
	mut source := src
	mut in_place := false
	if maker_x.window > 1 {
		loop_start = math.max(src_bounds.top, dst_bounds.top)
		loop_end = math.min(src_bounds.bottom, dst_bounds.bottom)
		mut pass := maker_x.pass()
		mut src_row := (loop_start - src_bounds.top) * src.width
		mut dst_row := (loop_start - dst_bounds.top) * dst.width
		for _ in loop_start .. loop_end {
			run_blur_pass(mut pass, src_bounds.left - dst_bounds.left, src_bounds.right - dst_bounds.left,
				dst_bounds.width(), src.pixels, src_row, 1, mut dst.pixels, dst_row, 1)
			src_row += src.width
			dst_row += dst.width
		}
		in_place = true
		loop_start = dst_bounds_in.left
		loop_end = dst_bounds_in.right
		dst_y_offset = dst_bounds_in.top - dst_bounds.top
		src_bounds = dst_bounds
		dst_bounds = dst_bounds_in
	}
	if maker_y.window > 1 {
		mut pass := maker_y.pass()
		source_width := if in_place { dst.width } else { source.width }
		mut src_col := loop_start - src_bounds.left
		mut dst_col := (loop_start - dst_bounds.left) + dst_y_offset * dst.width
		for _ in loop_start .. loop_end {
			if in_place {
				// The vertical pass reads and writes the horizontal pass's
				// pixels in place.
				run_blur_pass(mut pass, src_bounds.top - dst_bounds.top, src_bounds.bottom - dst_bounds.top,
					dst_bounds.height(), dst.pixels, src_col, source_width, mut dst.pixels, dst_col,
					dst.width)
			} else {
				run_blur_pass(mut pass, src_bounds.top - dst_bounds.top, src_bounds.bottom - dst_bounds.top,
					dst_bounds.height(), source.pixels, src_col, source_width, mut dst.pixels,
					dst_col, dst.width)
			}
			src_col++
			dst_col++
		}
	}
	subset := IRect{dst_bounds_in.left - dst_origin_x, dst_bounds_in.top - dst_origin_y, dst_bounds_in.right - dst_origin_x, dst_bounds_in.bottom - dst_origin_y}
	return dst, subset
}
