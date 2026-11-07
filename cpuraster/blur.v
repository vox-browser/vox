module cpuraster

import math

// SkBlurMaskFilterImpl (google/skia ee20d565) with kNormal_SkBlurStyle,
// as SkMaskFilter::MakeBlur() builds it for Canvas2D shadows: the sigma maps
// through the CTM (SkMatrix::mapRadius(), at most 128), rects and nested
// rects blur into a nine-patch (SkBlurMask::BlurRect()'s analytic profile for
// one rect, SkMaskBlurFilter for a ring), and other paths render into an A8
// mask that SkMaskBlurFilter blurs (a direct Gaussian kernel below sigma 2,
// three box passes above) before the blitter draws it.

const max_blur_sigma = f32(128)

// SkMaskFilter::MakeBlur(): a finite, positive sigma.
fn new_blur_sigma(sigma f32) ?f32 {
	if is_finite_f32(sigma) && sigma > 0 {
		return sigma
	}
	return none
}

// computeXformedSigma(): std::min(ctm.mapRadius(sigma), 128).
fn xformed_blur_sigma(sigma f32, m Matrix) f32 {
	x0 := sigma * m.a
	y0 := sigma * m.b
	x1 := sigma * m.c
	y1 := sigma * m.d
	d0 := point_length(x0, y0)
	d1 := point_length(x1, y1)
	product := d0 * d1
	radius := C.sqrtf(product)
	return if max_blur_sigma < radius { max_blur_sigma } else { radius }
}

// SkFloatingPoint's sk_float_saturate2int(): NaN maps to the largest int a
// float holds.
fn sk_saturate_int(v f32) int {
	max_fits := math.f32_from_bits(0x4effffff)
	min_fits := -max_fits
	if v != v {
		return int(max_fits)
	}
	mut x := if v < max_fits { v } else { max_fits }
	x = if x > min_fits { x } else { min_fits }
	return int(x)
}

@[inline]
fn sk_floor_int(v f32) int {
	return sk_saturate_int(floor_f32(v))
}

@[inline]
fn sk_ceil_int(v f32) int {
	return sk_saturate_int(ceil_f32(v))
}

// sk_float_round2int(): floor((double)x + 0.5).
@[inline]
fn sk_round_int(v f32) int {
	return sk_saturate_int(f32(math.floor(f64(v) + 0.5)))
}

fn rect_round_out(r Rect) IRect {
	return IRect{sk_floor_int(r.left), sk_floor_int(r.top), sk_ceil_int(r.right), sk_ceil_int(r.bottom)}
}

fn rect_round_in(r Rect) IRect {
	return IRect{sk_ceil_int(r.left), sk_ceil_int(r.top), sk_floor_int(r.right), sk_floor_int(r.bottom)}
}

// SkRect::contains(): false when either rect is empty.
fn rect_contains(r Rect, o Rect) bool {
	return !rect_is_empty(o) && !rect_is_empty(r) && r.left <= o.left && r.top <= o.top
		&& r.right >= o.right && r.bottom >= o.bottom
}

fn irect_outset(r IRect, dx int, dy int) IRect {
	return IRect{r.left - dx, r.top - dy, r.right + dx, r.bottom + dy}
}

// An A8 mask with its own pixels: row_bytes is the width unless noted.
fn new_a8_mask(bounds IRect, row_bytes int) Mask {
	return Mask{
		bounds:    bounds
		row_bytes: row_bytes
		image:     []u8{len: row_bytes * bounds.height()}
	}
}

// SkMaskBlurFilter: sigma pinned to [0, 135].
struct MaskBlurFilter {
	sigma f64
}

fn new_mask_blur_filter(sigma f32) MaskBlurFilter {
	s := f64(sigma)
	// SkTPin(): std::max(lo, std::min(x, hi)).
	low := if f64(135) < s { f64(135) } else { s }
	return MaskBlurFilter{
		sigma: if f64(0) < low { low } else { f64(0) }
	}
}

// hasNoBlur(): the historical 1/3 cutoff.
fn (f MaskBlurFilter) has_no_blur() bool {
	no_window := 1.0 / 3.0
	return f.sigma < no_window && f.sigma <= no_window
}

// The border blur() adds on each side.
fn (f MaskBlurFilter) border() int {
	if f.sigma < 2.0 {
		radius, _ := gauss_factors(f.sigma)
		return radius
	}
	return new_plan_gauss(f.sigma).border
}

// blur(): the blurred mask, outset by border() on every side, or none when
// the destination would not fit SkMaskBuilder::PrepareDestination()'s int
// limits.
fn (f MaskBlurFilter) blur(src &Mask) ?Mask {
	border := f.border()
	src_w := src.bounds.width()
	src_h := src.bounds.height()
	dst_w := i64(src_w) + 2 * i64(border)
	dst_h := i64(src_h) + 2 * i64(border)
	if dst_w > max_i32 || dst_h > max_i32 || dst_w * dst_h > max_i32 {
		return none
	}
	mut dst := new_a8_mask(irect_outset(src.bounds, border, border), int(dst_w))
	if f.sigma < 2.0 {
		small_blur(f.sigma, src, mut dst)
	} else {
		box_blur(new_plan_gauss(f.sigma), src, mut dst)
	}
	return dst
}

// SkGaussFilter's normalized Bessel factors for sigma < 2: the radius and
// the 0.16 fixed-point factors small_blur() multiplies by.
fn gauss_factors(sigma f64) (int, [6]u16) {
	variance := sigma * sigma
	besseli0 := fn (t f64) f64 {
		t2 := t * t
		quarter := t2 / 4.0
		mut sum := 1.0
		mut factor := 1.0
		mut k := 1
		for factor > 1.0 / 1000000.0 {
			step := quarter / f64(k * k)
			factor *= step
			sum += factor
			k++
		}
		return sum
	}
	besseli1 := fn (t f64) f64 {
		t2 := t * t
		quarter := t2 / 4.0
		mut sum := t / 2.0
		mut factor := sum
		mut k := 1
		for factor > 1.0 / 1000000.0 {
			step := quarter / f64(k * (k + 1))
			factor *= step
			sum += factor
			k++
		}
		return sum
	}
	d := C.exp(variance)
	mut b := [6]f64{}
	mut gauss := [6]f64{}
	b[0] = besseli0(variance)
	b[1] = besseli1(variance)
	gauss[0] = b[0] / d
	gauss[1] = b[1] / d
	mut n := 1
	for gauss[n] > 1.0 / 100.0 {
		ratio := -(f64(2 * n) / variance)
		scaled := ratio * b[n]
		b[n + 1] = scaled + b[n - 1]
		gauss[n + 1] = b[n + 1] / d
		n++
	}
	// normalize()
	mut sum := 0.0
	for i := n - 1; i >= 1; i-- {
		twice := 2 * gauss[i]
		sum += twice
	}
	sum += gauss[0]
	for i in 0 .. n {
		gauss[i] /= sum
	}
	sum = 0
	for i := n - 1; i >= 1; i-- {
		twice := 2 * gauss[i]
		sum += twice
	}
	gauss[0] = 1 - sum
	mut factors := [6]u16{}
	for i in 0 .. n {
		factors[i] = u16(math.round(gauss[i] * f64(1 << 16)))
	}
	return n - 1, factors
}

// mulhi() of 8.8 and 0.16 fixed-point lanes.
@[inline]
fn mulhi16(a u32, b u32) u32 {
	return (a * b) >> 16
}

// One output of blur_x_radius_N/blur_y_radius_N: kHalf plus the kernel's
// products of the 2r+1 inputs ending at m, in wrapping 16-bit lanes, then
// the 8.8 value's integer part.
@[inline]
fn gauss_tap(values []u8, start int, step int, count int, m int, radius int, factors [6]u16) u8 {
	mut acc := u32(0x80)
	for k in 0 .. 2 * radius + 1 {
		i := m - k
		if i < 0 || i >= count {
			continue
		}
		g := factors[if k > radius { k - radius } else { radius - k }]
		acc = (acc + mulhi16(u32(values[start + i * step]) << 8, g)) & 0xffff
	}
	return u8(acc >> 8)
}

// small_blur(): columns into the destination's middle, then rows in place.
fn small_blur(sigma f64, src &Mask, mut dst Mask) {
	radius, factors := gauss_factors(sigma)
	src_w := src.bounds.width()
	src_h := src.bounds.height()
	dst_w := dst.bounds.width()
	dst_h := dst.bounds.height()
	for x in 0 .. src_w {
		start := src.index(src.bounds.left + x, src.bounds.top)
		for m in 0 .. dst_h {
			dst.image[m * dst.row_bytes + radius + x] = gauss_tap(src.image, start, src.row_bytes,
				src_h, m, radius, factors)
		}
	}
	mut row := []u8{len: src_w}
	for y in 0 .. dst_h {
		o := y * dst.row_bytes
		for x in 0 .. src_w {
			row[x] = dst.image[o + radius + x]
		}
		for m in 0 .. dst_w {
			dst.image[o + m] = gauss_tap(row, 0, 1, src_w, m, radius, factors)
		}
	}
}

// PlanGauss: three box passes approximating a Gaussian.
struct PlanGauss {
	weight         u64
	border         int
	sliding_window int
	pass0          int
	pass1          int
	pass2          int
}

fn new_plan_gauss(sigma f64) PlanGauss {
	scaled := sigma * 3
	spread := scaled * math.sqrt(2 * math.pi)
	quarter := spread / 4
	possible := int(math.floor(quarter + 0.5))
	window := if possible > 1 { possible } else { 1 }
	odd := window & 1 == 1
	border := if odd { 3 * ((window - 1) / 2) } else { 3 * (window / 2) - 1 }
	window2 := window * window
	window3 := window2 * window
	divisor := if odd { window3 } else { window3 + window2 }
	inverse := 1.0 / f64(divisor)
	weight := inverse * f64(u64(1) << 32)
	return PlanGauss{
		weight:         u64(math.round(weight))
		border:         border
		sliding_window: 2 * border + 1
		pass0:          window - 1
		pass1:          window - 1
		pass2:          if odd { window - 1 } else { window }
	}
}

@[inline]
fn (p &PlanGauss) final_scale(sum u32) u8 {
	return u8((p.weight * u64(sum) + (u64(1) << 31)) >> 32)
}

// PlanGauss::Scan::blur(): count source values from src[src_start] into
// dst_count destination values dst_stride apart from dst[dst_start].
fn (p &PlanGauss) scan(src []u8, src_start int, count int, mut dst []u8, dst_start int, dst_stride int, dst_count int, mut buffer []u32) {
	b0 := 0
	b0_end := p.pass0
	b1 := b0_end
	b1_end := b1 + p.pass1
	b2 := b1_end
	b2_end := b2 + p.pass2
	no_change := if p.sliding_window > count { p.sliding_window - count } else { 0 }
	for i in 0 .. b2_end {
		buffer[i] = 0
	}
	mut c0 := b0
	mut c1 := b1
	mut c2 := b2
	mut sum0 := u32(0)
	mut sum1 := u32(0)
	mut sum2 := u32(0)
	mut d := dst_start
	for i in 0 .. count + no_change {
		leading := if i < count { u32(src[src_start + i]) } else { u32(0) }
		sum0 += leading
		sum1 += sum0
		sum2 += sum1
		dst[d] = p.final_scale(sum2)
		sum2 -= buffer[c2]
		buffer[c2] = sum1
		c2 = if c2 + 1 < b2_end { c2 + 1 } else { b2 }
		sum1 -= buffer[c1]
		buffer[c1] = sum0
		c1 = if c1 + 1 < b1_end { c1 + 1 } else { b1 }
		sum0 -= buffer[c0]
		buffer[c0] = leading
		c0 = if c0 + 1 < b0_end { c0 + 1 } else { b0 }
		d += dst_stride
	}
	// Starting from the right, fill in the rest of the buffer.
	for i in 0 .. b2_end {
		buffer[i] = 0
	}
	sum0 = 0
	sum1 = 0
	sum2 = 0
	mut cursor := dst_start + dst_count * dst_stride
	mut s := src_start + count
	for cursor > d {
		cursor -= dst_stride
		s--
		leading := u32(src[s])
		sum0 += leading
		sum1 += sum0
		sum2 += sum1
		dst[cursor] = p.final_scale(sum2)
		sum2 -= buffer[c2]
		buffer[c2] = sum1
		c2 = if c2 + 1 < b2_end { c2 + 1 } else { b2 }
		sum1 -= buffer[c1]
		buffer[c1] = sum0
		c1 = if c1 + 1 < b1_end { c1 + 1 } else { b1 }
		sum0 -= buffer[c0]
		buffer[c0] = leading
		c0 = if c0 + 1 < b0_end { c0 + 1 } else { b0 }
	}
}

// SkMaskBlurFilter::blur() for sigma >= 2: rows into a transposed buffer,
// then its rows into the destination's columns.
fn box_blur(plan PlanGauss, src &Mask, mut dst Mask) {
	src_w := src.bounds.width()
	src_h := src.bounds.height()
	dst_w := dst.bounds.width()
	dst_h := dst.bounds.height()
	mut buffer := []u32{len: plan.pass0 + plan.pass1 + plan.pass2}
	tmp_w := src_h
	tmp_h := dst_w
	mut tmp := []u8{len: tmp_w * tmp_h}
	for y in 0 .. src_h {
		plan.scan(src.image, src.index(src.bounds.left, src.bounds.top + y), src_w, mut tmp,
			y, tmp_w, tmp_h, mut buffer)
	}
	for y in 0 .. tmp_h {
		plan.scan(tmp, y * tmp_w, tmp_w, mut dst.image, y, dst.row_bytes, dst_h, mut buffer)
	}
}

// SkBlurMask's gaussianIntegral(): the integral of a box-cubed kernel
// approximating a Gaussian, from x to infinity.
fn gaussian_integral(x f32) f32 {
	if x > 1.5 {
		return 0
	}
	if x < -1.5 {
		return 1
	}
	x2 := x * x
	x3 := x2 * x
	if x > 0.5 {
		a := x3 / f32(6)
		b := f32(3) * x2
		c := b * f32(0.25)
		e := a - c
		f := f32(1.125) * x
		g := e + f
		return f32(0.5625) - g
	}
	if x > -0.5 {
		a := f32(0.75) * x
		b := x3 / f32(3)
		c := a - b
		return f32(0.5) - c
	}
	a := -x3 / f32(6)
	b := f32(3) * x2
	c := b * f32(0.25)
	e := a - c
	f := f32(1.125) * x
	g := e - f
	return f32(0.4375) + g
}

// ComputeBlurProfile(): the inverted profile of a blurred half-plane.
fn blur_profile(size int, sigma f32) []u8 {
	mut profile := []u8{len: size}
	center := size >> 1
	twice := f32(2) * sigma
	invr := f32(1) / twice
	profile[0] = 255
	for x in 1 .. size {
		offset := f32(center - x) - f32(0.5)
		scaled := offset * invr
		gi := gaussian_integral(scaled)
		profile[x] = u8(255 - int(u8(f32(255) * gi)))
	}
	return profile
}

// ComputeBlurredScanline(), with its unsigned arithmetic.
fn blurred_scanline(profile []u8, width int, sigma f32) []u8 {
	mut pixels := []u8{len: width}
	six := f32(6) * sigma
	profile_size := u32(sk_ceil_int(six))
	sw := u32(width) - profile_size
	center := int(profile_size & ~u32(1)) - 1
	w := int(sw - u32(center))
	twice := f32(2) * sigma
	for x in 0 .. width {
		if profile_size <= sw {
			// ProfileLookup()
			dx := math.abs(((x << 1) + 1) - width) - w
			ox := if dx >> 1 < 0 { 0 } else { dx >> 1 }
			pixels[x] = profile[ox]
		} else {
			span := f32(sw) / twice
			half := f32(u32(x)) + f32(0.5)
			ratio := half / twice
			gi_x := f32(1.5) - ratio
			a := gaussian_integral(gi_x)
			b := gaussian_integral(gi_x + span)
			pixels[x] = u8(f32(255) * (a - b))
		}
	}
	return pixels
}

// SkBlurMask::BlurRect()'s bounds and margin: none when the profile is empty.
fn blur_rect_bounds(sigma f32, r Rect) ?(IRect, int) {
	six := f32(6) * sigma
	profile_size := sk_ceil_int(six)
	if profile_size <= 0 {
		return none
	}
	pad := profile_size / 2
	pad_f := f32(pad)
	return IRect{sk_round_int(r.left - pad_f), sk_round_int(r.top - pad_f), sk_round_int(r.right +
		pad_f), sk_round_int(r.bottom + pad_f)}, pad
}

// SkBlurMask::BlurRect(): the product of horizontal and vertical profiles.
fn blur_rect(sigma f32, r Rect) ?Mask {
	bounds, _ := blur_rect_bounds(sigma, r)?
	if i64(bounds.width()) * i64(bounds.height()) <= 0
		|| i64(bounds.width()) * i64(bounds.height()) > max_i32 {
		return none
	}
	six := f32(6) * sigma
	profile := blur_profile(sk_ceil_int(six), sigma)
	mut mask := new_a8_mask(bounds, bounds.width())
	horizontal := blurred_scanline(profile, bounds.width(), sigma)
	vertical := blurred_scanline(profile, bounds.height(), sigma)
	for y in 0 .. bounds.height() {
		for x in 0 .. bounds.width() {
			mask.image[y * mask.row_bytes + x] = u8(mul_div255_round(horizontal[x], vertical[y]))
		}
	}
	return mask
}

// A nine-patch: the small blurred mask (at the origin), the destination
// rect it stretches over and its stretchable center pixel.
struct NinePatch {
	mask     Mask
	outer    IRect
	center_x int
	center_y int
}

enum FilterReturn {
	false_
	true_
	unimplemented
	// The mask's anti-aliased fill would fall back to SkScan::FillPath(),
	// which cpuraster does not port.
	declined
}

fn rect_exceeds(r Rect, v f32) bool {
	return r.left < -v || r.top < -v || r.right > v || r.bottom > v || r.right - r.left > v
		|| r.bottom - r.top > v
}

// SkBlurMaskFilterImpl::filterRectsToNine() for one rect or a ring.
fn filter_rects_to_nine(rects []Rect, sigma f32) (FilterReturn, NinePatch) {
	if rect_exceeds(rects[0], 32767) {
		return .unimplemented, NinePatch{}
	}
	src_bounds := rect_round_out(rects[0])
	mut dst_bounds := IRect{}
	if rects.len == 1 {
		bounds, _ := blur_rect_bounds(sigma, rects[0]) or { return .false_, NinePatch{} }
		dst_bounds = bounds
	} else {
		filter := new_mask_blur_filter(sigma)
		if filter.has_no_blur() {
			return .false_, NinePatch{}
		}
		border := filter.border()
		dst_bounds = irect_outset(src_bounds, border, border)
	}
	mut small_w := dst_bounds.width() - src_bounds.width() + 2
	mut small_h := dst_bounds.height() - src_bounds.height() + 2
	mut inner := src_bounds
	mut center_x := 0
	mut center_y := 0
	if rects.len == 1 {
		center_x = small_w
		center_y = small_h
	} else {
		inner = rect_round_in(rects[1])
		center_x = small_w + (inner.left - src_bounds.left)
		center_y = small_h + (inner.top - src_bounds.top)
	}
	small_w += 1
	small_h += 1
	dx := f32(inner.width() - small_w)
	dy := f32(inner.height() - small_h)
	if dx < 0 || dy < 0 {
		return .unimplemented, NinePatch{}
	}
	mut small := []Rect{}
	small << Rect{rects[0].left, rects[0].top, rects[0].right - dx, rects[0].bottom - dy}
	if small[0].right - small[0].left < 2 || small[0].bottom - small[0].top < 2 {
		return .unimplemented, NinePatch{}
	}
	if rects.len == 2 {
		small << Rect{rects[1].left, rects[1].top, rects[1].right - dx, rects[1].bottom - dy}
	}
	mut filtered := Mask{}
	if rects.len == 2 {
		src, status := draw_rects_into_mask(small)
		match status {
			.ok {}
			.empty { return .false_, NinePatch{} }
			.declined { return .declined, NinePatch{} }
		}
		filtered = new_mask_blur_filter(sigma).blur(&src) or { return .false_, NinePatch{} }
	} else {
		filtered = blur_rect(sigma, small[0]) or { return .false_, NinePatch{} }
	}
	filtered = Mask{
		...filtered
		bounds: IRect{0, 0, filtered.bounds.width(), filtered.bounds.height()}
	}
	return .true_, NinePatch{filtered, dst_bounds, center_x, center_y}
}

// How rendering a mask went.
enum MaskStatus {
	ok
	// Nothing to render: Skia's caller draws the path unfiltered.
	empty
	// The anti-aliased fill would fall back to SkScan::FillPath() because
	// the mask is more than 8191 pixels across.
	declined
}

// draw_rects_into_mask() for a ring: the even-odd pair of rects filled
// anti-aliased into a zeroed mask with 4-byte aligned rows.
fn draw_rects_into_mask(rects []Rect) (Mask, MaskStatus) {
	bounds := rect_round_out(rects[0])
	row_bytes := (bounds.width() + 3) & ~3
	if i64(row_bytes) * i64(bounds.height()) <= 0 {
		return Mask{}, .empty
	}
	mut mask := new_a8_mask(bounds, row_bytes)
	mut b := PathBuilder{}
	for r in rects {
		b.add_rect_dir(r, true, 0)
	}
	b.fill_type = .even_odd
	path := b.detach()
	translate := Matrix{
		e: f32(-bounds.left)
		f: f32(-bounds.top)
	}
	rc := RasterClip{
		is_bw: true
		rect:  IRect{0, 0, bounds.width(), bounds.height()}
	}
	mut blitter := A8Blitter{
		width:     bounds.width()
		height:    bounds.height()
		row_bytes: row_bytes
		src:       255
		pixels:    mask.image
	}
	if !anti_fill_path_clip(path.transform(translate), false, &rc, mut blitter) {
		return mask, .declined
	}
	return mask, .ok
}

// SkAAClipBlitterWrapper: the blitter and the region rect a clip resolves to.
fn clip_wrapper(rc &RasterClip, blitter Blitter) (Blitter, IRect) {
	if rc.is_bw {
		return blitter, rc.rect
	}
	return Blitter(new_aaclip_blitter(blitter, &rc.aa)), rc.aa.bounds
}

fn blit_clipped_mask(mut blitter Blitter, mask &Mask, bounds IRect, clip IRect) {
	if r := bounds.intersect(clip) {
		blitter.blit_mask(mask, r)
	}
}

// extract_mask_subset(): bounds of mask, moved to (x, y).
fn mask_subset(mask &Mask, bounds IRect, x int, y int) Mask {
	return Mask{
		bounds:    IRect{x, y, x + bounds.width(), y + bounds.height()}
		row_bytes: mask.row_bytes
		offset:    mask.index(bounds.left, bounds.top)
		image:     mask.image
	}
}

// draw_nine_clipped(): the corners from the small mask, the stretched edges
// as anti-aliased runs and repeated rows, and the center when filled.
fn draw_nine_clipped(patch &NinePatch, fill_center bool, clip IRect, mut blitter Blitter) {
	mask := &patch.mask
	outer := patch.outer
	cx := patch.center_x
	cy := patch.center_y
	mb := mask.bounds
	corners := [
		IRect{mb.left, mb.top, cx, cy},
		IRect{cx + 1, mb.top, mb.right, cy},
		IRect{mb.left, cy + 1, cx, mb.bottom},
		IRect{cx + 1, cy + 1, mb.right, mb.bottom},
	]
	for i, bounds in corners {
		if bounds.width() > 0 && bounds.height() > 0 {
			x := if i == 1 || i == 3 { outer.right - bounds.width() } else { outer.left }
			y := if i >= 2 { outer.bottom - bounds.height() } else { outer.top }
			m := mask_subset(mask, bounds, x, y)
			blit_clipped_mask(mut blitter, &m, m.bounds, clip)
		}
	}
	inner := IRect{outer.left + cx - mb.left, outer.top + cy - mb.top, outer.right + (cx + 1 - mb.right), outer.bottom + (cy + 1 - mb.bottom)}
	if fill_center {
		if r := inner.intersect(clip) {
			blitter.blit_rect(r.left, r.top, r.width(), r.height())
		}
	}
	top := IRect{inner.left, outer.top, inner.right, inner.top}
	bottom := IRect{inner.left, inner.bottom, inner.right, outer.bottom}
	left_edge := IRect{outer.left, inner.top, inner.left, inner.bottom}
	right_edge := IRect{inner.right, inner.top, outer.right, inner.bottom}
	if r := top.intersect(clip) {
		start_y := if r.top - outer.top > 0 { r.top - outer.top } else { 0 }
		for y in start_y .. start_y + r.height() {
			mut runs := []i16{len: r.width() + 1}
			mut alpha := []u8{len: r.width() + 1}
			runs[0] = i16(r.width())
			alpha[0] = mask.image[mask.index(cx, mb.top + y)]
			blitter.blit_anti_h(r.left, outer.top + y, mut alpha, mut runs)
		}
	}
	if r := bottom.intersect(clip) {
		start_y := outer.bottom - r.bottom
		for y in start_y .. start_y + r.height() {
			mut runs := []i16{len: r.width() + 1}
			mut alpha := []u8{len: r.width() + 1}
			runs[0] = i16(r.width())
			alpha[0] = mask.image[mask.index(cx, mb.bottom - y - 1)]
			blitter.blit_anti_h(r.left, outer.bottom - y - 1, mut alpha, mut runs)
		}
	}
	// left and right: one mask row repeated for every row.
	if r := left_edge.intersect(clip) {
		left := Mask{
			bounds:    r
			row_bytes: 0
			offset:    mask.index(mb.left + r.left - outer.left, mb.top + cy)
			image:     mask.image
		}
		blitter.blit_mask(&left, r)
	}
	if r := right_edge.intersect(clip) {
		right := Mask{
			bounds:    r
			row_bytes: 0
			offset:    mask.index(mb.right - outer.right + r.left, mb.top + cy)
			image:     mask.image
		}
		blitter.blit_mask(&right, r)
	}
}

// draw_nine(): through the clip's region.
fn draw_nine(patch &NinePatch, fill_center bool, rc &RasterClip, blitter Blitter) {
	mut wrapped, region := clip_wrapper(rc, blitter)
	if clip := region.intersect(patch.outer) {
		draw_nine_clipped(patch, fill_center, clip, mut wrapped)
	}
}

// compute_mask_bounds(): the path bounds outset by half a pixel, limited to
// the clip outset by the blur's margin (at most 128).
fn compute_mask_bounds(path_bounds Rect, clip_bounds IRect, filter MaskBlurFilter) ?IRect {
	outset := Rect{path_bounds.left - f32(0.5), path_bounds.top - f32(0.5), path_bounds.right +
		f32(0.5), path_bounds.bottom + f32(0.5)}
	bounds := rect_round_out(outset)
	if filter.has_no_blur() {
		return none
	}
	margin := filter.border()
	limit := if margin < 128 { margin } else { 128 }
	return bounds.intersect(irect_outset(clip_bounds, limit, limit))
}

// skcpu::DrawToMask(): the device path filled or hairlined (always with
// butt caps) into a zeroed A8 mask through SkA8_Blitter. The path keeps the
// convexity its device form had.
fn draw_path_to_mask(path Path, convex bool, clip_bounds IRect, filter MaskBlurFilter, hairline bool) (Mask, MaskStatus) {
	if path.verbs.len == 0 {
		return Mask{}, .empty
	}
	path_bounds := path.bounds() or { return Mask{}, .empty }
	bounds := compute_mask_bounds(path_bounds, clip_bounds, filter) or { return Mask{}, .empty }
	if i64(bounds.width()) * i64(bounds.height()) > max_i32 {
		return Mask{}, .empty
	}
	mut mask := new_a8_mask(bounds, bounds.width())
	translate := Matrix{
		e: f32(-bounds.left)
		f: f32(-bounds.top)
	}
	local := path.transform(translate)
	local_bounds := local.bounds() or { return mask, .ok }
	if !is_finite_f32(local_bounds.left) || !is_finite_f32(local_bounds.top)
		|| !is_finite_f32(local_bounds.right) || !is_finite_f32(local_bounds.bottom) {
		return mask, .ok
	}
	rc := RasterClip{
		is_bw: true
		rect:  IRect{0, 0, bounds.width(), bounds.height()}
	}
	mut blitter := A8Blitter{
		width:     bounds.width()
		height:    bounds.height()
		row_bytes: bounds.width()
		src:       255
		pixels:    mask.image
	}
	if hairline {
		anti_hair_path_clip(local, .butt, &rc, mut blitter)
	} else if !anti_fill_path_convex(local, convex, &rc, mut blitter) {
		return mask, .declined
	}
	return mask, .ok
}

// SkPathPriv::TooBigForMath(): Draw::drawDevPath() draws nothing past a
// quarter of the float range.
fn too_big_for_math(bounds Rect) bool {
	limit := f32(3.4028235e38) * f32(0.25)
	return !(bounds.left >= -limit && bounds.top >= -limit && bounds.right <= limit
		&& bounds.bottom <= limit)
}

// What SkMaskFilterBase::filterPath() does for the blur, worked out before
// any pixel is drawn.
enum BlurPlanKind {
	// filterPath() returns false: the caller draws the path unfiltered.
	unfiltered
	nine
	mask
	// The blur needs SkScan::FillPath(); the caller declines the draw.
	declined
}

struct BlurPlan {
	kind        BlurPlanKind
	patch       NinePatch
	fill_center bool
	mask        Mask
}

// plan_blur() renders and blurs the device path's mask, or the nine-patch
// of its rect or ring. The path keeps the convexity its device form had.
fn plan_blur(path Path, convex bool, sigma f32, m Matrix, rc &RasterClip, hairline bool) BlurPlan {
	xformed := xformed_blur_sigma(sigma, m)
	if !hairline {
		mut rects := nested_fill_rects(path)
		if rects.len == 0 {
			if r := path.is_rect() {
				rects << r
			}
		}
		if rects.len > 0 {
			result, patch := filter_rects_to_nine(rects, xformed)
			match result {
				.false_ {
					return BlurPlan{
						kind: .unfiltered
					}
				}
				.true_ {
					return BlurPlan{
						kind:        .nine
						patch:       patch
						fill_center: rects.len == 1
					}
				}
				.declined {
					return BlurPlan{
						kind: .declined
					}
				}
				.unimplemented {}
			}
		}
	}
	filter := new_mask_blur_filter(xformed)
	src, status := draw_path_to_mask(path, convex, rc.bounds(), filter, hairline)
	match status {
		.ok {}
		.empty {
			return BlurPlan{
				kind: .unfiltered
			}
		}
		.declined {
			return BlurPlan{
				kind: .declined
			}
		}
	}
	dst := filter.blur(&src) or {
		return BlurPlan{
			kind: .unfiltered
		}
	}
	return BlurPlan{
		kind: .mask
		mask: dst
	}
}

// draw() blits a nine-patch or mask plan through the clip.
fn (plan &BlurPlan) draw(rc &RasterClip, blitter Blitter) {
	match plan.kind {
		.nine {
			draw_nine(&plan.patch, plan.fill_center, rc, blitter)
		}
		.mask {
			mut wrapped, region := clip_wrapper(rc, blitter)
			if clip := region.intersect(plan.mask.bounds) {
				wrapped.blit_mask(&plan.mask, clip)
			}
		}
		else {}
	}
}

// SkPathPriv::IsNestedFillRects(): two rect contours, one inside the other,
// outer first; empty otherwise.
fn nested_fill_rects(p Path) []Rect {
	if p.segment_mask() != segment_line {
		return []
	}
	first := rect_contour_in(p.points, p.verbs, true) or { return [] }
	second := rect_contour_in(p.points[first.points_consumed..], p.verbs[first.verbs_consumed..],
		false) or { return [] }
	if rect_contains(first.rect, second.rect) {
		return [first.rect, second.rect]
	}
	if rect_contains(second.rect, first.rect) {
		return [second.rect, first.rect]
	}
	return []
}

// SkPathPriv::IsRectContour() over a span of a path whose segments are all
// lines, with the points and verbs it consumed.
struct RectContourSpan {
	rect            Rect
	closed          bool
	points_consumed int
	verbs_consumed  int
}

fn rect_contour_in(pts []Point, verbs []PathVerb, allow_partial bool) ?RectContourSpan {
	if pts.len < 4 || verbs.len < 4 {
		return none
	}
	if r := trivial_rect(pts, verbs) {
		return RectContourSpan{r, true, pts.len, verbs.len}
	}
	mut curr := 0
	mut corners := 0
	mut line_start := Point{}
	mut first_pt := -1
	mut last_pt := -1
	mut pi := 0
	mut save_pts := -1
	mut first_corner := Point{}
	mut third_corner := Point{}
	mut directions := [-1, -1, -1, -1, -1]
	mut closed_or_moved := false
	mut auto_close := false
	mut insert_close := false
	for curr < verbs.len && (!allow_partial || !auto_close) {
		verb := if insert_close { PathVerb.close } else { verbs[curr] }
		match verb {
			.close, .line {
				if verb == .close {
					save_pts = pi
					auto_close = true
					insert_close = false
				} else {
					last_pt = pi
				}
				line_end := if verb == .close { pts[first_pt] } else { pts[pi] }
				if verb != .close {
					pi++
				}
				delta := Point{line_end.x - line_start.x, line_end.y - line_start.y}
				if delta.x != 0 && delta.y != 0 {
					return none
				}
				if !is_finite_f32(delta.x) || !is_finite_f32(delta.y) {
					return none
				}
				if line_start != line_end {
					next_direction := rect_make_dir(delta.x, delta.y)
					if corners == 0 {
						directions[0] = next_direction
						corners = 1
						closed_or_moved = false
						line_start = line_end
					} else {
						if closed_or_moved {
							return none
						}
						if !(auto_close && next_direction == directions[0]) {
							closed_or_moved = auto_close
							if directions[corners - 1] == next_direction {
								if corners == 3 && verb == .line {
									third_corner = line_end
								}
								line_start = line_end
							} else {
								directions[corners] = next_direction
								corners++
								match corners {
									2 {
										first_corner = line_start
									}
									3 {
										if directions[0] ^ directions[2] != 2 {
											return none
										}
										third_corner = line_end
									}
									4 {
										if directions[1] ^ directions[3] != 2 {
											return none
										}
									}
									else {
										return none
									}
								}
								line_start = line_end
							}
						}
					}
				}
			}
			.quad, .conic, .cubic {
				return none
			}
			.move {
				if allow_partial && !auto_close && directions[0] >= 0 {
					// Close the contour, then try the move again.
					insert_close = true
					curr--
					continue
				}
				if corners == 0 {
					first_pt = pi
				} else {
					close_x := pts[first_pt].x - pts[last_pt].x
					close_y := pts[first_pt].y - pts[last_pt].y
					if close_x != 0 && close_y != 0 {
						return none
					}
				}
				line_start = pts[pi]
				pi++
				closed_or_moved = true
			}
		}
		curr++
	}
	if corners < 3 || corners > 4 {
		return none
	}
	close_x := pts[first_pt].x - pts[last_pt].x
	close_y := pts[first_pt].y - pts[last_pt].y
	if close_x != 0 && close_y != 0 {
		return none
	}
	return RectContourSpan{sorted_rect(first_corner, third_corner), auto_close, if save_pts >= 0 {
		save_pts
	} else {
		0
	}, curr}
}
