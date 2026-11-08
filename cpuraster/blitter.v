module cpuraster

// SkBlitter (google/skia ee20d565): the calls a scan converter makes for
// spans, anti-aliased runs, columns, rectangles and coverage masks. Methods
// Skia does not override use the default_* functions, like SkBlitter's base
// implementations.

// An A8 coverage mask; pixel (x, y) is image[offset + (y - top) * row_bytes + x - left].
struct Mask {
	bounds    IRect
	row_bytes int
	offset    int
mut:
	image []u8
}

@[inline]
fn (m &Mask) index(x int, y int) int {
	return m.offset + (y - m.bounds.top) * m.row_bytes + x - m.bounds.left
}

// Anti-aliased runs pass their alpha and run-length arrays as slices that
// share the caller's storage, so wrappers can break runs in place (SkAlphaRuns).
interface Blitter {
mut:
	blit_h(x int, y int, width int)
	blit_anti_h(x int, y int, mut aa []u8, mut runs []i16)
	blit_v(x int, y int, height int, alpha u8)
	blit_rect(x int, y int, width int, height int)
	blit_anti_rect(x int, y int, width int, height int, left_alpha u8, right_alpha u8)
	blit_mask(mask &Mask, clip IRect)
	blit_anti_h2(x int, y int, a0 u8, a1 u8)
	blit_anti_v2(x int, y int, a0 u8, a1 u8)
}

// A transparent/invalid paint shader can suppress A8 masks while a color
// glyph in the same run still draws as a sprite with its own shader.
struct NullBlitter {}

fn (mut b NullBlitter) blit_h(x int, y int, width int) {}

fn (mut b NullBlitter) blit_anti_h(x int, y int, mut aa []u8, mut runs []i16) {}

fn (mut b NullBlitter) blit_v(x int, y int, height int, alpha u8) {}

fn (mut b NullBlitter) blit_rect(x int, y int, width int, height int) {}

fn (mut b NullBlitter) blit_anti_rect(x int, y int, width int, height int, left_alpha u8, right_alpha u8) {}

fn (mut b NullBlitter) blit_mask(mask &Mask, clip IRect) {}

fn (mut b NullBlitter) blit_anti_h2(x int, y int, a0 u8, a1 u8) {}

fn (mut b NullBlitter) blit_anti_v2(x int, y int, a0 u8, a1 u8) {}

fn default_blit_anti_rect(mut b Blitter, x_in int, y int, width int, height int, left_alpha u8, right_alpha u8) {
	mut x := x_in
	if left_alpha > 0 {
		b.blit_v(x, y, height, left_alpha)
	}
	x++
	if width > 0 {
		b.blit_rect(x, y, width, height)
		x += width
	}
	if right_alpha > 0 {
		b.blit_v(x, y, height, right_alpha)
	}
}

fn default_blit_anti_h2(mut b Blitter, x int, y int, a0 u8, a1 u8) {
	mut runs := [i16(1), 1, 0]
	mut aa := [a0, a1]
	b.blit_anti_h(x, y, mut aa, mut runs)
}

fn default_blit_anti_v2(mut b Blitter, x int, y int, a0 u8, a1 u8) {
	mut runs := [i16(1), 0]
	mut aa := [a0]
	b.blit_anti_h(x, y, mut aa, mut runs)
	runs = [i16(1), 0]
	aa = [a1]
	b.blit_anti_h(x, y + 1, mut aa, mut runs)
}

// scalar_to_alpha() in SkBlitter.cpp.
fn scalar_to_alpha(a f32) u8 {
	product := a * 255
	alpha := u8(saturate_to_i32(product))
	return if alpha > 247 {
		255
	} else if alpha < 8 {
		0
	} else {
		alpha
	}
}

// SkBlitter::blitFatAntiRect().
fn blit_fat_anti_rect(mut b Blitter, rect Rect) {
	bounds := round_out(rect)
	if bounds.height() == 0 {
		return
	}
	width := bounds.width()
	mut runs := []i16{len: width + 1}
	mut alphas := []u8{len: width + 1}
	runs[0] = 1
	runs[1] = i16(width - 2)
	runs[width - 1] = 1
	runs[width] = 0
	partial_l := f32(bounds.left + 1) - rect.left
	partial_r := rect.right - f32(bounds.right - 1)
	mut partial_t := f32(bounds.top + 1) - rect.top
	partial_b := rect.bottom - f32(bounds.bottom - 1)
	if bounds.height() == 1 {
		partial_t = rect.bottom - rect.top
	}
	alphas[0] = scalar_to_alpha(partial_l * partial_t)
	alphas[1] = scalar_to_alpha(partial_t)
	alphas[width - 1] = scalar_to_alpha(partial_r * partial_t)
	b.blit_anti_h(bounds.left, bounds.top, mut alphas, mut runs)
	if bounds.height() > 2 {
		b.blit_anti_rect(bounds.left, bounds.top + 1, width - 2, bounds.height() - 2,
			scalar_to_alpha(partial_l), scalar_to_alpha(partial_r))
	}
	if bounds.height() > 1 {
		alphas[0] = scalar_to_alpha(partial_l * partial_b)
		alphas[1] = scalar_to_alpha(partial_b)
		alphas[width - 1] = scalar_to_alpha(partial_r * partial_b)
		b.blit_anti_h(bounds.left, bounds.bottom - 1, mut alphas, mut runs)
	}
}

// SkRect::roundOut() with saturating float-to-int conversion.
fn round_out(r Rect) IRect {
	return IRect{saturate_to_i32(floor_f32(r.left)), saturate_to_i32(floor_f32(r.top)), saturate_to_i32(ceil_f32(r.right)), saturate_to_i32(ceil_f32(r.bottom))}
}

@[inline]
fn floor_f32(v f32) f32 {
	return f32(C.floorf(v))
}

@[inline]
fn ceil_f32(v f32) f32 {
	return f32(C.ceilf(v))
}

fn C.floorf(x f32) f32
fn C.ceilf(x f32) f32

// SkAlphaRuns::BreakAt().
fn alpha_runs_break_at(mut runs []i16, mut alpha []u8, start int, x_in int) {
	mut x := x_in
	mut i := start
	for x > 0 {
		n := int(runs[i])
		if x < n {
			alpha[i + x] = alpha[i]
			runs[i] = i16(x)
			runs[i + x] = i16(n - x)
			break
		}
		i += n
		x -= n
	}
}

fn compute_anti_width(runs []i16) int {
	mut width := 0
	mut i := 0
	for {
		count := int(runs[i])
		if count == 0 {
			break
		}
		width += count
		i += count
	}
	return width
}

// SkRectClipBlitter.
struct RectClipBlitter {
	clip IRect
mut:
	inner Blitter
}

@[inline]
fn y_in_rect(y int, r IRect) bool {
	return u32(y - r.top) < u32(r.height())
}

@[inline]
fn x_in_rect(x int, r IRect) bool {
	return u32(x - r.left) < u32(r.width())
}

fn (mut c RectClipBlitter) blit_h(left_in int, y int, width_in int) {
	if !y_in_rect(y, c.clip) {
		return
	}
	mut left := left_in
	mut right := left_in + width_in
	if left < c.clip.left {
		left = c.clip.left
	}
	if right > c.clip.right {
		right = c.clip.right
	}
	width := right - left
	if width > 0 {
		c.inner.blit_h(left, y, width)
	}
}

fn (mut c RectClipBlitter) blit_anti_h(left int, y int, mut aa []u8, mut runs []i16) {
	if !y_in_rect(y, c.clip) || left >= c.clip.right {
		return
	}
	mut x0 := left
	mut x1 := left + compute_anti_width(runs)
	if x1 <= c.clip.left {
		return
	}
	mut start := 0
	if x0 < c.clip.left {
		dx := c.clip.left - x0
		alpha_runs_break_at(mut runs, mut aa, 0, dx)
		start = dx
		x0 = c.clip.left
	}
	if x1 > c.clip.right {
		x1 = c.clip.right
		alpha_runs_break_at(mut runs, mut aa, start, x1 - x0)
		runs[start + x1 - x0] = 0
	}
	mut sub_aa := unsafe { aa[start..] }
	mut sub_runs := unsafe { runs[start..] }
	c.inner.blit_anti_h(x0, y, mut sub_aa, mut sub_runs)
}

fn (mut c RectClipBlitter) blit_v(x int, y int, height int, alpha u8) {
	if !x_in_rect(x, c.clip) {
		return
	}
	mut y0 := y
	mut y1 := y + height
	if y0 < c.clip.top {
		y0 = c.clip.top
	}
	if y1 > c.clip.bottom {
		y1 = c.clip.bottom
	}
	if y0 < y1 {
		c.inner.blit_v(x, y0, y1 - y0, alpha)
	}
}

fn (mut c RectClipBlitter) blit_rect(left int, y int, width int, height int) {
	if r := IRect{left, y, left + width, y + height}.intersect(c.clip) {
		c.inner.blit_rect(r.left, r.top, r.width(), r.height())
	}
}

fn (mut c RectClipBlitter) blit_anti_rect(left int, y int, width int, height int, left_alpha_in u8, right_alpha_in u8) {
	r := IRect{left, y, left + width + 2, y + height}.intersect(c.clip) or { return }
	mut left_alpha := left_alpha_in
	mut right_alpha := right_alpha_in
	if r.left != left {
		left_alpha = 255
	}
	if r.right != left + width + 2 {
		right_alpha = 255
	}
	if left_alpha == 255 && right_alpha == 255 {
		c.inner.blit_rect(r.left, r.top, r.width(), r.height())
	} else if r.width() == 1 {
		if r.left == left {
			c.inner.blit_v(r.left, r.top, r.height(), left_alpha)
		} else {
			c.inner.blit_v(r.left, r.top, r.height(), right_alpha)
		}
	} else {
		c.inner.blit_anti_rect(r.left, r.top, r.width() - 2, r.height(), left_alpha, right_alpha)
	}
}

fn (mut c RectClipBlitter) blit_mask(mask &Mask, clip IRect) {
	if r := clip.intersect(c.clip) {
		c.inner.blit_mask(mask, r)
	}
}

fn (mut c RectClipBlitter) blit_anti_h2(x int, y int, a0 u8, a1 u8) {
	default_blit_anti_h2(mut c, x, y, a0, a1)
}

fn (mut c RectClipBlitter) blit_anti_v2(x int, y int, a0 u8, a1 u8) {
	default_blit_anti_v2(mut c, x, y, a0, a1)
}

// SkA8_Blitter with the src-over procs for a solid alpha source.
pub struct A8Blitter {
	width     int
	height    int
	row_bytes int
	src       u8
mut:
	pixels []u8
}

@[inline]
fn a8_div255(prod u32) u8 {
	return u8(((prod + 128) * 257) >> 16)
}

@[inline]
fn a8_srcover(src u8, dst u8) u8 {
	return src + a8_div255(u32(255 - src) * u32(dst))
}

fn (mut b A8Blitter) row_bw(offset int, count int) {
	for i in 0 .. count {
		b.pixels[offset + i] = a8_srcover(b.src, b.pixels[offset + i])
	}
}

// A8_row_aa() with canFoldAA for src-over.
fn (mut b A8Blitter) row_aa(offset int, count int, aa u8) {
	src := a8_div255(u32(b.src) * u32(aa))
	for i in 0 .. count {
		b.pixels[offset + i] = a8_srcover(src, b.pixels[offset + i])
	}
}

fn (mut b A8Blitter) blit_h(x int, y int, width int) {
	b.row_bw(y * b.row_bytes + x, width)
}

fn (mut b A8Blitter) blit_anti_h(x int, y int, mut aa []u8, mut runs []i16) {
	mut offset := y * b.row_bytes + x
	mut i := 0
	for {
		count := int(runs[i])
		if count == 0 {
			return
		}
		if aa[i] == 255 {
			b.row_bw(offset, count)
		} else if aa[i] != 0 {
			b.row_aa(offset, count, aa[i])
		}
		i += count
		offset += count
	}
}

fn (mut b A8Blitter) blit_v(x int, y int, height int, alpha u8) {
	mut offset := y * b.row_bytes + x
	for _ in 0 .. height {
		if alpha == 255 {
			b.pixels[offset] = a8_srcover(b.src, b.pixels[offset])
		} else if alpha != 0 {
			b.row_aa(offset, 1, alpha)
		}
		offset += b.row_bytes
	}
}

fn (mut b A8Blitter) blit_rect(x int, y int, width int, height int) {
	for row in 0 .. height {
		b.row_bw((y + row) * b.row_bytes + x, width)
	}
}

fn (mut b A8Blitter) blit_anti_rect(x int, y int, width int, height int, left_alpha u8, right_alpha u8) {
	default_blit_anti_rect(mut b, x, y, width, height, left_alpha, right_alpha)
}

fn (mut b A8Blitter) blit_mask(mask &Mask, clip IRect) {
	for row in 0 .. clip.height() {
		dst := (clip.top + row) * b.row_bytes + clip.left
		src := mask.index(clip.left, clip.top + row)
		for i in 0 .. clip.width() {
			d := b.pixels[dst + i]
			blended := a8_srcover(b.src, d)
			t := mask.image[src + i]
			b.pixels[dst + i] = a8_div255(u32(255 - t) * u32(d) + u32(t) * u32(blended))
		}
	}
}

fn (mut b A8Blitter) blit_anti_h2(x int, y int, a0 u8, a1 u8) {
	default_blit_anti_h2(mut b, x, y, a0, a1)
}

fn (mut b A8Blitter) blit_anti_v2(x int, y int, a0 u8, a1 u8) {
	default_blit_anti_v2(mut b, x, y, a0, a1)
}
