module cpuraster

import math
import math.bits

// SkScan_AAAPath.cpp, SkScan_AntiPath.cpp and SkEdgeBuilder.cpp (google/skia
// ee20d565): analytic anti-aliased path filling. Coverage reaches the real
// blitter through the same calls as Skia, so blending is reproduced exactly.

// SkAlphaRuns over shared run-length and alpha arrays.
@[inline]
fn catch_overflow(alpha int) u8 {
	return u8(alpha - (alpha >> 8))
}

fn break_runs(mut runs []i16, mut alpha []u8, base int, x_in int, count int) {
	mut x := x_in
	mut i := base
	next := base + x_in
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
	i = next
	x = count
	for {
		n := int(runs[i])
		if x < n {
			alpha[i + x] = alpha[i]
			runs[i] = i16(x)
			runs[i + x] = i16(n - x)
			break
		}
		x -= n
		if x <= 0 {
			break
		}
		i += n
	}
}

// SkAlphaRuns::add(); returns the next offsetX.
fn alpha_runs_add(mut runs []i16, mut alpha []u8, x_in int, start_alpha int, middle_count_in int, stop_alpha int, max_value int, offset_x int) int {
	mut base := offset_x
	mut last := base
	mut x := x_in - offset_x
	mut middle_count := middle_count_in
	if start_alpha != 0 {
		break_runs(mut runs, mut alpha, base, x, 1)
		tmp := int(alpha[base + x]) + start_alpha
		alpha[base + x] = u8(tmp - (tmp >> 8))
		base += x + 1
		x = 0
	}
	if middle_count != 0 {
		break_runs(mut runs, mut alpha, base, x, middle_count)
		base += x
		x = 0
		for {
			alpha[base] = catch_overflow(int(alpha[base]) + max_value)
			n := int(runs[base])
			base += n
			middle_count -= n
			if middle_count <= 0 {
				break
			}
		}
		last = base
	}
	if stop_alpha != 0 {
		break_runs(mut runs, mut alpha, base, x, 1)
		base += x
		alpha[base] = u8(int(alpha[base]) + stop_alpha)
		last = base
	}
	return last
}

enum AdditiveKind {
	mask
	rle
	safe_rle
}

struct AdditiveBlitter {
	kind AdditiveKind
mut:
	real Blitter
	// MaskAdditiveBlitter
	mask      Mask
	mask_clip IRect
	row_y     int
	row_base  int
	// RunBasedAdditiveBlitter
	curr_y   int
	width    int
	left     int
	top      int
	runs     []i16
	alpha    []u8
	offset_x int
}

const mask_max_width = 32
const mask_max_storage = 1024

fn mask_can_handle_rect(bounds IRect) bool {
	width := bounds.width()
	if width > mask_max_width {
		return false
	}
	rb := i64((width + 3) & ~3)
	storage := rb * i64(bounds.height())
	return width <= mask_max_width && storage <= mask_max_storage
}

fn new_mask_blitter(real Blitter, ir IRect, clip_bounds IRect) AdditiveBlitter {
	// One extra byte at either end absorbs precision errors, as in Skia.
	storage := ir.height() * ir.width() + 2
	clip := ir.intersect(clip_bounds) or { IRect{} }
	return AdditiveBlitter{
		kind:      .mask
		real:      real
		mask:      Mask{
			bounds:    ir
			row_bytes: ir.width()
			offset:    1
			image:     []u8{len: storage + 2}
		}
		mask_clip: clip
		row_y:     ir.top - 1
	}
}

fn new_rle_blitter(real Blitter, ir IRect, clip_bounds IRect, is_inverse bool, safe bool) AdditiveBlitter {
	sect := if is_inverse { clip_bounds } else { ir.intersect(clip_bounds) or { IRect{} } }
	width := sect.right - sect.left
	mut b := AdditiveBlitter{
		kind:   if safe { AdditiveKind.safe_rle } else { AdditiveKind.rle }
		real:   real
		left:   sect.left
		width:  width
		top:    sect.top
		curr_y: sect.top - 1
		runs:   []i16{len: width + 1}
		alpha:  []u8{len: width + 2}
	}
	b.reset_runs()
	return b
}

fn (mut b AdditiveBlitter) reset_runs() {
	b.runs[0] = i16(b.width)
	b.runs[b.width] = 0
	b.alpha[0] = 0
}

// MaskAdditiveBlitter::getRow(): index of x = 0 in the mask's row y.
fn (mut b AdditiveBlitter) get_row(y int) int {
	if y != b.row_y {
		b.row_y = y
		b.row_base = b.mask.offset + (y - b.mask.bounds.top) * b.mask.row_bytes - b.mask.bounds.left
	}
	return b.row_base
}

@[inline]
fn snap_alpha(alpha u8) u8 {
	return if alpha > 247 {
		255
	} else if alpha < 8 {
		0
	} else {
		alpha
	}
}

fn (mut b AdditiveBlitter) runs_empty() bool {
	return b.alpha[0] == 0 && b.runs[int(b.runs[0])] == 0
}

fn (mut b AdditiveBlitter) flush() {
	if b.curr_y >= b.top {
		mut x := 0
		for b.runs[x] != 0 {
			b.alpha[x] = snap_alpha(b.alpha[x])
			x += int(b.runs[x])
		}
		if !b.runs_empty() {
			b.real.blit_anti_h(b.left, b.curr_y, mut b.alpha, mut b.runs)
			b.reset_runs()
			b.offset_x = 0
		}
		b.curr_y = b.top - 1
	}
}

fn (mut b AdditiveBlitter) check_y(y int) {
	if y != b.curr_y {
		b.flush()
		b.curr_y = y
	}
}

fn (mut b AdditiveBlitter) flush_if_y_changed(y i32, next_y i32) {
	if b.kind != .mask && fixed_floor_to_int(y) != fixed_floor_to_int(next_y) {
		b.flush()
	}
}

// The destructors: blit the mask, or flush the last row.
fn (mut b AdditiveBlitter) finish() {
	if b.kind == .mask {
		b.real.blit_mask(&b.mask, b.mask_clip)
	} else {
		b.flush()
	}
}

fn add_alpha(mut alpha []u8, index int, delta u8) {
	alpha[index] = catch_overflow(int(alpha[index]) + int(delta))
}

fn safely_add_alpha(mut alpha []u8, index int, delta u8) {
	alpha[index] = u8(math.min(255, int(alpha[index]) + int(delta)))
}

// blitAntiH(x, y, antialias[], len).
fn (mut b AdditiveBlitter) blit_anti_h_array(x_in int, y int, antialias []u8, start_in int, len_in int) {
	mut x := x_in
	mut start := start_in
	mut len := len_in
	b.check_y(y)
	x -= b.left
	if x < 0 {
		len += x
		start -= x
		x = 0
	}
	len = math.min(len, b.width - x)
	if x < b.offset_x {
		b.offset_x = 0
	}
	b.offset_x = alpha_runs_add(mut b.runs, mut b.alpha, x, 0, len, 0, 0, b.offset_x)
	mut i := 0
	for i < len {
		run := int(b.runs[x + i])
		for j in 1 .. run {
			b.runs[x + i + j] = 1
			b.alpha[x + i + j] = b.alpha[x + i]
		}
		b.runs[x + i] = 1
		i += run
	}
	for k in 0 .. len {
		if b.kind == .safe_rle {
			safely_add_alpha(mut b.alpha, x + k, antialias[start + k])
		} else {
			add_alpha(mut b.alpha, x + k, antialias[start + k])
		}
	}
}

// blitAntiH(x, y, alpha).
fn (mut b AdditiveBlitter) blit_anti_h1(x_in int, y int, alpha u8) {
	if b.kind == .mask {
		row := b.get_row(y)
		add_alpha(mut b.mask.image, row + x_in, alpha)
		return
	}
	b.check_y(y)
	x := x_in - b.left
	if x < b.offset_x {
		b.offset_x = 0
	}
	if x >= 0 && x + 1 <= b.width {
		if b.kind == .safe_rle {
			b.offset_x = alpha_runs_add(mut b.runs, mut b.alpha, x, 0, 1, 0, 0, b.offset_x)
			safely_add_alpha(mut b.alpha, x, alpha)
		} else {
			b.offset_x = alpha_runs_add(mut b.runs, mut b.alpha, x, 0, 1, 0, int(alpha),
				b.offset_x)
		}
	}
}

// blitAntiH(x, y, width, alpha).
fn (mut b AdditiveBlitter) blit_anti_hw(x_in int, y int, width int, alpha u8) {
	if b.kind == .mask {
		row := b.get_row(y)
		for i in 0 .. width {
			add_alpha(mut b.mask.image, row + x_in + i, alpha)
		}
		return
	}
	b.check_y(y)
	x := x_in - b.left
	if x < b.offset_x {
		b.offset_x = 0
	}
	if x >= 0 && x + width <= b.width {
		if b.kind == .safe_rle {
			b.offset_x = alpha_runs_add(mut b.runs, mut b.alpha, x, 0, width, 0, 0, b.offset_x)
			mut i := x
			for i < x + width {
				safely_add_alpha(mut b.alpha, i, alpha)
				i += int(b.runs[i])
			}
		} else {
			b.offset_x = alpha_runs_add(mut b.runs, mut b.alpha, x, 0, width, 0, int(alpha),
				b.offset_x)
		}
	}
}

// getRealBlitter()->blitV() etc.: the mask blitter sets its own alphas.
fn (mut b AdditiveBlitter) real_blit_v(x int, y int, height int, alpha u8) {
	if b.kind != .mask {
		b.real.blit_v(x, y, height, alpha)
		return
	}
	if alpha == 0 {
		return
	}
	mut row := b.get_row(y)
	for _ in 0 .. height {
		b.mask.image[row + x] = alpha
		row += b.mask.row_bytes
	}
}

fn (mut b AdditiveBlitter) real_blit_rect(x int, y int, width int, height int) {
	if b.kind != .mask {
		b.real.blit_rect(x, y, width, height)
		return
	}
	mut row := b.get_row(y)
	for _ in 0 .. height {
		for i in 0 .. width {
			b.mask.image[row + x + i] = 255
		}
		row += b.mask.row_bytes
	}
}

fn (mut b AdditiveBlitter) real_blit_anti_rect(x int, y int, width int, height int, left_alpha u8, right_alpha u8) {
	if b.kind != .mask {
		b.real.blit_anti_rect(x, y, width, height, left_alpha, right_alpha)
		return
	}
	b.real_blit_v(x, y, height, left_alpha)
	b.real_blit_v(x + 1 + width, y, height, right_alpha)
	b.real_blit_rect(x + 1, y, width, height)
}

// Trapezoid coverage helpers.
@[inline]
fn trapezoid_to_alpha(l1 i32, l2 i32) u8 {
	area := (l1 + l2) / 2
	return u8(area >> 8)
}

@[inline]
fn partial_triangle_to_alpha(a i32, b i32) u8 {
	area := (a >> 11) * (a >> 11) * (b >> 11)
	return u8((area >> 8) & 0xff)
}

@[inline]
fn get_partial_alpha_fixed(alpha u8, partial_height i32) u8 {
	return u8((i32(alpha) * partial_height + fixed_half) >> 16)
}

@[inline]
fn get_partial_alpha(alpha u8, full_alpha u8) u8 {
	return u8((int(alpha) * int(full_alpha)) >> 8)
}

@[inline]
fn fixed_to_alpha(f i32) u8 {
	return get_partial_alpha_fixed(255, f)
}

fn approximate_intersection(l1_in i32, r1_in i32, l2_in i32, r2_in i32) i32 {
	mut l1 := l1_in
	mut r1 := r1_in
	mut l2 := l2_in
	mut r2 := r2_in
	if l1 > r1 {
		l1, r1 = r1, l1
	}
	if l2 > r2 {
		l2, r2 = r2, l2
	}
	lo := if l1 > l2 { l1 } else { l2 }
	hi := if r1 < r2 { r1 } else { r2 }
	return (lo + hi) / 2
}

fn sat_add32(a i32, b i32) i32 {
	sum := i64(a) + i64(b)
	return if sum > max_i32 {
		max_i32
	} else if sum < min_i32 {
		min_i32
	} else {
		i32(sum)
	}
}

fn compute_alpha_above_line(mut alphas []u8, base int, l i32, r i32, dy i32, full_alpha u8) {
	big_r := fixed_ceil_to_int(r)
	if big_r == 0 {
		return
	} else if big_r == 1 {
		alphas[base] = get_partial_alpha(u8((((i32(big_r) << 17) - l - r) >> 9)), full_alpha)
	} else {
		first := fixed1 - l
		last := r - (i32(big_r - 1) << 16)
		first_h := fixed_mul(first, dy)
		alphas[base] = u8(fixed_mul(first, first_h) >> 9)
		mut alpha16 := sat_add32(first_h, dy >> 1)
		for i in 1 .. big_r - 1 {
			alphas[base + i] = u8(alpha16 >> 8)
			alpha16 = sat_add32(alpha16, dy)
		}
		alphas[base + big_r - 1] = u8(int(full_alpha) - int(partial_triangle_to_alpha(last, dy)))
	}
}

fn compute_alpha_below_line(mut alphas []u8, base int, l i32, r i32, dy i32, full_alpha u8) {
	big_r := fixed_ceil_to_int(r)
	if big_r == 0 {
		return
	} else if big_r == 1 {
		alphas[base] = get_partial_alpha(trapezoid_to_alpha(l, r), full_alpha)
	} else {
		first := fixed1 - l
		last := r - (i32(big_r - 1) << 16)
		last_h := fixed_mul(last, dy)
		alphas[base + big_r - 1] = u8(fixed_mul(last, last_h) >> 9)
		mut alpha16 := sat_add32(last_h, dy >> 1)
		for i := big_r - 2; i > 0; i-- {
			alphas[base + i] = u8((alpha16 >> 8) & 0xff)
			alpha16 = sat_add32(alpha16, dy)
		}
		alphas[base] = u8(int(full_alpha) - int(partial_triangle_to_alpha(first, dy)))
	}
}

// mask_row is the index of x = 0 in the mask row (possibly negative), or
// no_mask_row without a mask.
const no_mask_row = min_i32

fn blit_single_alpha(mut b AdditiveBlitter, y int, x int, alpha u8, full_alpha u8, mask_row int, no_real_blitter bool) {
	if mask_row != no_mask_row {
		if full_alpha == 255 && !no_real_blitter {
			b.mask.image[mask_row + x] = alpha
		} else {
			safely_add_alpha(mut b.mask.image, mask_row + x, get_partial_alpha(alpha, full_alpha))
		}
	} else {
		if full_alpha == 255 && !no_real_blitter {
			b.real_blit_v(x, y, 1, alpha)
		} else {
			b.blit_anti_h1(x, y, get_partial_alpha(alpha, full_alpha))
		}
	}
}

fn blit_two_alphas(mut b AdditiveBlitter, y int, x int, a1 u8, a2 u8, full_alpha u8, mask_row int, no_real_blitter bool) {
	if mask_row != no_mask_row {
		safely_add_alpha(mut b.mask.image, mask_row + x, a1)
		safely_add_alpha(mut b.mask.image, mask_row + x + 1, a2)
	} else {
		if full_alpha == 255 && !no_real_blitter {
			b.real.blit_anti_h2(x, y, a1, a2)
		} else {
			b.blit_anti_h1(x, y, a1)
			b.blit_anti_h1(x + 1, y, a2)
		}
	}
}

fn blit_full_alpha(mut b AdditiveBlitter, y int, x int, len int, full_alpha u8, mask_row int, no_real_blitter bool) {
	if mask_row != no_mask_row {
		for i in 0 .. len {
			safely_add_alpha(mut b.mask.image, mask_row + x + i, full_alpha)
		}
	} else {
		if full_alpha == 255 && !no_real_blitter {
			b.real.blit_h(x, y, len)
		} else {
			b.blit_anti_hw(x, y, len, full_alpha)
		}
	}
}

fn blit_aaa_trapezoid_row(mut b AdditiveBlitter, y int, ul i32, ur i32, ll i32, lr i32, l_dy i32, r_dy i32, full_alpha u8, mask_row int, no_real_blitter bool) {
	big_l := fixed_floor_to_int(ul)
	big_r := fixed_ceil_to_int(lr)
	len := big_r - big_l
	if len == 1 {
		alpha := trapezoid_to_alpha(ur - ul, lr - ll)
		blit_single_alpha(mut b, y, big_l, alpha, full_alpha, mask_row, no_real_blitter)
		return
	}
	mut alphas := []u8{len: len + 1, init: full_alpha}
	mut temp_alphas := []u8{len: len + 1}
	mut runs := []i16{len: len + 1, init: 1}
	runs[len] = 0
	u_l := fixed_floor_to_int(ul)
	l_l := fixed_ceil_to_int(ll)
	if u_l + 2 == l_l {
		first := int_to_fixed(u_l) + fixed1 - ul
		second := ll - ul - first
		a1 := u8(int(full_alpha) - int(partial_triangle_to_alpha(first, l_dy)))
		a2 := partial_triangle_to_alpha(second, l_dy)
		alphas[0] = if alphas[0] > a1 { alphas[0] - a1 } else { 0 }
		alphas[1] = if alphas[1] > a2 { alphas[1] - a2 } else { 0 }
	} else {
		compute_alpha_below_line(mut temp_alphas, u_l - big_l, ul - int_to_fixed(u_l),
			ll - int_to_fixed(u_l), l_dy, full_alpha)
		for i in u_l .. l_l {
			if alphas[i - big_l] > temp_alphas[i - big_l] {
				alphas[i - big_l] -= temp_alphas[i - big_l]
			} else {
				alphas[i - big_l] = 0
			}
		}
	}
	u_r := fixed_floor_to_int(ur)
	l_r := fixed_ceil_to_int(lr)
	if u_r + 2 == l_r {
		first := int_to_fixed(u_r) + fixed1 - ur
		second := lr - ur - first
		a1 := partial_triangle_to_alpha(first, r_dy)
		a2 := u8(int(full_alpha) - int(partial_triangle_to_alpha(second, r_dy)))
		alphas[len - 2] = if alphas[len - 2] > a1 { alphas[len - 2] - a1 } else { 0 }
		alphas[len - 1] = if alphas[len - 1] > a2 { alphas[len - 1] - a2 } else { 0 }
	} else {
		compute_alpha_above_line(mut temp_alphas, u_r - big_l, ur - int_to_fixed(u_r),
			lr - int_to_fixed(u_r), r_dy, full_alpha)
		for i in u_r .. l_r {
			if alphas[i - big_l] > temp_alphas[i - big_l] {
				alphas[i - big_l] -= temp_alphas[i - big_l]
			} else {
				alphas[i - big_l] = 0
			}
		}
	}
	if mask_row != no_mask_row {
		for i in 0 .. len {
			safely_add_alpha(mut b.mask.image, mask_row + big_l + i, alphas[i])
		}
	} else {
		if full_alpha == 255 && !no_real_blitter {
			b.real.blit_anti_h(big_l, y, mut alphas, mut runs)
		} else {
			b.blit_anti_h_array(big_l, y, alphas, 0, len)
		}
	}
}

fn blit_trapezoid_row(mut b AdditiveBlitter, y int, ul_in i32, ur_in i32, ll_in i32, lr_in i32, l_dy i32, r_dy i32, full_alpha u8, mask_row int, no_real_blitter bool) {
	mut ul := ul_in
	mut ur := ur_in
	mut ll := ll_in
	mut lr := lr_in
	if ul > ur {
		return
	}
	if ll > lr {
		ll = approximate_intersection(ul, ll, ur, lr)
		lr = ll
	}
	if ul == ur && ll == lr {
		return
	}
	if ul > ll {
		ul, ll = ll, ul
	}
	if ur > lr {
		ur, lr = lr, ur
	}
	join_left := fixed_ceil_to_fixed(ll)
	join_rite := fixed_floor_to_fixed(ur)
	if join_left <= join_rite {
		if ul < join_left {
			len := fixed_ceil_to_int(join_left - ul)
			if len == 1 {
				alpha := trapezoid_to_alpha(join_left - ul, join_left - ll)
				blit_single_alpha(mut b, y, int(ul >> 16), alpha, full_alpha, mask_row,
					no_real_blitter)
			} else if len == 2 {
				first := join_left - fixed1 - ul
				second := ll - ul - first
				a1 := partial_triangle_to_alpha(first, l_dy)
				a2 := u8(int(full_alpha) - int(partial_triangle_to_alpha(second, l_dy)))
				blit_two_alphas(mut b, y, int(ul >> 16), a1, a2, full_alpha, mask_row,
					no_real_blitter)
			} else {
				blit_aaa_trapezoid_row(mut b, y, ul, join_left, ll, join_left, l_dy, max_i32,
					full_alpha, mask_row, no_real_blitter)
			}
		}
		if join_left < join_rite {
			blit_full_alpha(mut b, y, fixed_floor_to_int(join_left), fixed_floor_to_int(join_rite - join_left),
				full_alpha, mask_row, no_real_blitter)
		}
		if lr > join_rite {
			len := fixed_ceil_to_int(lr - join_rite)
			if len == 1 {
				alpha := trapezoid_to_alpha(ur - join_rite, lr - join_rite)
				blit_single_alpha(mut b, y, int(join_rite >> 16), alpha, full_alpha, mask_row,
					no_real_blitter)
			} else if len == 2 {
				first := join_rite + fixed1 - ur
				second := lr - ur - first
				a1 := u8(int(full_alpha) - int(partial_triangle_to_alpha(first, r_dy)))
				a2 := partial_triangle_to_alpha(second, r_dy)
				blit_two_alphas(mut b, y, int(join_rite >> 16), a1, a2, full_alpha, mask_row,
					no_real_blitter)
			} else {
				blit_aaa_trapezoid_row(mut b, y, join_rite, ur, join_rite, lr, max_i32, r_dy,
					full_alpha, mask_row, no_real_blitter)
			}
		}
	} else {
		blit_aaa_trapezoid_row(mut b, y, ul, ur, ll, lr, l_dy, r_dy, full_alpha, mask_row,
			no_real_blitter)
	}
}

// The doubly linked edge list, with sentinel head and tail entries.
struct EdgeList {
mut:
	edges []Edge
	head  int
	tail  int
}

fn compare_edges(a &Edge, b &Edge) bool {
	if a.upper_y != b.upper_y {
		return a.upper_y < b.upper_y
	}
	if a.x != b.x {
		return a.x < b.x
	}
	return a.dx < b.dx
}

// SkTQSort() of edge indices with compare_edges().
fn sort_edge_indices(edges []Edge, mut list []int) {
	n := list.len
	if n <= 1 {
		return
	}
	depth := 2 * next_log2(n - 1)
	intro_sort(edges, mut list, depth, 0, n)
}

fn next_log2(value int) int {
	return 32 - bits.leading_zeros_32(u32(value - 1))
}

fn intro_sort(edges []Edge, mut list []int, depth_in int, left_in int, count_in int) {
	mut depth := depth_in
	mut left := left_in
	mut count := count_in
	for {
		if count <= 32 {
			insertion_sort(edges, mut list, left, count)
			return
		}
		if depth == 0 {
			heap_sort(edges, mut list, left, count)
			return
		}
		depth--
		middle := left + ((count - 1) >> 1)
		pivot := sort_partition(edges, mut list, left, count, middle)
		pivot_count := pivot - left
		intro_sort(edges, mut list, depth, left, pivot_count)
		left += pivot_count + 1
		count -= pivot_count + 1
	}
}

fn insertion_sort(edges []Edge, mut list []int, left int, count int) {
	right := left + count - 1
	for next := left + 1; next <= right; next++ {
		if !compare_edges(&edges[list[next]], &edges[list[next - 1]]) {
			continue
		}
		insert := list[next]
		mut hole := next
		for {
			list[hole] = list[hole - 1]
			hole--
			if !(left < hole && compare_edges(&edges[insert], &edges[list[hole - 1]])) {
				break
			}
		}
		list[hole] = insert
	}
}

fn sort_partition(edges []Edge, mut list []int, left_in int, count int, pivot int) int {
	mut left := left_in
	right := left + count - 1
	pivot_value := list[pivot]
	list[pivot], list[right] = list[right], list[pivot]
	mut new_pivot := left
	for left < right {
		if compare_edges(&edges[list[left]], &edges[pivot_value]) {
			list[left], list[new_pivot] = list[new_pivot], list[left]
			new_pivot++
		}
		left++
	}
	list[new_pivot], list[right] = list[right], list[new_pivot]
	return new_pivot
}

fn heap_sort(edges []Edge, mut list []int, base int, count int) {
	for i := count >> 1; i > 0; i-- {
		heap_sift_down(edges, mut list, base, i, count)
	}
	for i := count - 1; i > 0; i-- {
		list[base], list[base + i] = list[base + i], list[base]
		heap_sift_up(edges, mut list, base, 1, i)
	}
}

fn heap_sift_up(edges []Edge, mut list []int, base int, root_in int, bottom int) {
	mut root := root_in
	x := list[base + root - 1]
	start := root
	mut j := root * 2
	for j <= bottom {
		if j < bottom && compare_edges(&edges[list[base + j - 1]], &edges[list[base + j]]) {
			j++
		}
		list[base + root - 1] = list[base + j - 1]
		root = j
		j = root * 2
	}
	j = root / 2
	for j >= start {
		if compare_edges(&edges[list[base + j - 1]], &edges[x]) {
			list[base + root - 1] = list[base + j - 1]
			root = j
			j = root / 2
		} else {
			break
		}
	}
	list[base + root - 1] = x
}

fn heap_sift_down(edges []Edge, mut list []int, base int, root_in int, bottom int) {
	mut root := root_in
	x := list[base + root - 1]
	mut child := root * 2
	for child <= bottom {
		if child < bottom && compare_edges(&edges[list[base + child - 1]], &edges[list[base + child]]) {
			child++
		}
		if compare_edges(&edges[x], &edges[list[base + child - 1]]) {
			list[base + root - 1] = list[base + child - 1]
			root = child
			child = root * 2
		} else {
			break
		}
	}
	list[base + root - 1] = x
}

// SkAnalyticEdgeBuilder.
struct EdgeBuilder {
mut:
	edges []Edge
	list  []int
}

fn is_vertical_line(e &Edge) bool {
	return e.dx == 0 && e.edge_type == edge_line
}

enum Combine {
	no
	partial
	total
}

// SkAnalyticEdgeBuilder::combineVertical().
fn combine_vertical(edge &Edge, mut last Edge) Combine {
	if last.edge_type != edge_line || last.dx != 0 || edge.x != last.x {
		return .no
	}
	if edge.winding == last.winding {
		if edge.lower_y == last.upper_y {
			last.upper_y = edge.upper_y
			last.y = last.upper_y
			return .partial
		}
		if approximately_equal(edge.upper_y, last.lower_y) {
			last.lower_y = edge.lower_y
			return .partial
		}
		return .no
	}
	if approximately_equal(edge.upper_y, last.upper_y) {
		if approximately_equal(edge.lower_y, last.lower_y) {
			return .total
		}
		if edge.lower_y < last.lower_y {
			last.upper_y = edge.lower_y
			last.y = last.upper_y
			return .partial
		}
		last.upper_y = last.lower_y
		last.y = last.upper_y
		last.lower_y = edge.lower_y
		last.winding = edge.winding
		return .partial
	}
	if approximately_equal(edge.lower_y, last.lower_y) {
		if edge.upper_y > last.upper_y {
			last.lower_y = edge.upper_y
			return .partial
		}
		last.lower_y = last.upper_y
		last.upper_y = edge.upper_y
		last.y = last.upper_y
		last.winding = edge.winding
		return .partial
	}
	return .no
}

@[inline]
fn approximately_equal(a i32, b i32) bool {
	return abs32(a - b) < 0x100
}

fn (mut b EdgeBuilder) add_line(p0 Point, p1 Point) {
	mut edge := Edge{}
	if !edge.set_line(p0, p1) {
		return
	}
	mut combine := Combine.no
	if is_vertical_line(&edge) && b.list.len > 0 {
		last := b.list.last()
		combine = combine_vertical(&edge, mut b.edges[last])
	}
	match combine {
		.total {
			b.list.delete_last()
		}
		.partial {}
		.no {
			b.list << b.edges.len
			b.edges << edge
		}
	}
}

fn (mut b EdgeBuilder) add_quad(pts []Point) {
	mut edge := Edge{}
	if edge.set_quadratic(pts) {
		b.list << b.edges.len
		b.edges << edge
	}
}

fn (mut b EdgeBuilder) add_cubic(pts []Point) {
	mut edge := Edge{}
	if edge.set_cubic(pts) {
		b.list << b.edges.len
		b.edges << edge
	}
}

// SkPathEdgeIter: each segment, closing every contour with a line.
struct PathEdge {
	verb   PathVerb
	pts    []Point
	weight f32
}

fn path_edges(path Path) []PathEdge {
	mut result := []PathEdge{}
	mut pi := 0
	mut wi := 0
	mut move_pt := Point{}
	mut last_pt := Point{}
	mut needs_close_line := false
	for verb in path.verbs {
		match verb {
			.move {
				if needs_close_line {
					result << PathEdge{.line, [last_pt, move_pt], 0}
					needs_close_line = false
				}
				move_pt = path.points[pi]
				last_pt = move_pt
				pi++
			}
			.close {
				if needs_close_line {
					result << PathEdge{.line, [last_pt, move_pt], 0}
					needs_close_line = false
				}
			}
			else {
				count := verb_point_count(verb)
				mut pts := [last_pt]
				for i in 0 .. count {
					pts << path.points[pi + i]
				}
				pi += count
				last_pt = pts.last()
				mut w := f32(0)
				if verb == .conic {
					w = path.weights[wi]
					wi++
				}
				result << PathEdge{verb, pts, w}
				needs_close_line = true
			}
		}
	}
	if needs_close_line {
		result << PathEdge{.line, [last_pt, move_pt], 0}
	}
	return result
}

const conic_tolerance = f32(0.25)

// SkEdgeBuilder::buildEdges().
fn build_edges(path Path, clip ?Rect, convex bool) EdgeBuilder {
	can_cull_to_the_right := !convex
	mut b := EdgeBuilder{}
	edges := path_edges(path)
	if path.segment_mask() == segment_line {
		// buildPoly()
		for e in edges {
			if c := clip {
				lines := clip_line(e.pts, c, can_cull_to_the_right)
				for i in 0 .. lines.len - 1 {
					b.add_line(lines[i], lines[i + 1])
				}
			} else {
				b.add_line(e.pts[0], e.pts[1])
			}
		}
		return b
	}
	if c := clip {
		mut clipper := EdgeClipper{
			can_cull_to_the_right: can_cull_to_the_right
		}
		mut finite := true
		for e in edges {
			clipper.segments.clear()
			match e.verb {
				.line {
					clipper.clip_line(e.pts[0], e.pts[1], c)
				}
				.quad {
					clipper.clip_quad(e.pts, c)
				}
				.conic {
					quads := conic_to_quads(e.pts, e.weight, conic_tolerance)
					for i := 0; i + 2 < quads.len; i += 2 {
						clipper.clip_quad(quads[i..i + 3], c)
					}
				}
				.cubic {
					clipper.clip_cubic(e.pts, c)
				}
				else {}
			}
			for segment in clipper.segments {
				for p in segment.pts {
					if !is_finite_f32(p.x) || !is_finite_f32(p.y) {
						finite = false
					}
				}
				if !finite {
					break
				}
				match segment.verb {
					.line { b.add_line(segment.pts[0], segment.pts[1]) }
					.quad { b.add_quad(segment.pts) }
					.cubic { b.add_cubic(segment.pts) }
					else {}
				}
			}
			if !finite {
				break
			}
		}
		if !finite {
			b.list.clear()
		}
		return b
	}
	for e in edges {
		match e.verb {
			.line {
				b.add_line(e.pts[0], e.pts[1])
			}
			.quad {
				b.add_mono_y_quads(e.pts)
			}
			.conic {
				quads := conic_to_quads(e.pts, e.weight, conic_tolerance)
				for i := 0; i + 2 < quads.len; i += 2 {
					b.add_mono_y_quads(quads[i..i + 3])
				}
			}
			.cubic {
				mono := chop_cubic_at_extrema(e.pts, true)
				for i := 0; i * 3 + 3 < mono.len; i++ {
					b.add_cubic(mono[i * 3..i * 3 + 4])
				}
			}
			else {}
		}
	}
	return b
}

fn (mut b EdgeBuilder) add_mono_y_quads(pts []Point) {
	mono := chop_quad_at_extrema(pts, true)
	for i := 0; i * 2 + 2 < mono.len; i++ {
		b.add_quad(mono[i * 2..i * 2 + 3])
	}
}

fn (mut l EdgeList) remove_edge(i int) {
	prev := l.edges[i].prev
	next := l.edges[i].next
	l.edges[prev].next = next
	l.edges[next].prev = prev
}

fn (mut l EdgeList) insert_edge_after(i int, after int) {
	l.edges[i].prev = after
	l.edges[i].next = l.edges[after].next
	l.edges[l.edges[after].next].prev = i
	l.edges[after].next = i
}

fn (mut l EdgeList) backward_insert_edge_based_on_x(i int) {
	x := l.edges[i].x
	mut prev := l.edges[i].prev
	for l.edges[prev].prev >= 0 && l.edges[prev].x > x {
		prev = l.edges[prev].prev
	}
	if l.edges[prev].next != i {
		l.remove_edge(i)
		l.insert_edge_after(i, prev)
	}
}

fn (l &EdgeList) backward_insert_start(prev_in int, x i32) int {
	mut prev := prev_in
	for l.edges[prev].prev >= 0 && l.edges[prev].x > x {
		prev = l.edges[prev].prev
	}
	return prev
}

fn is_smooth_enough_edge(e &Edge, next &Edge) bool {
	if e.curve_count < 0 {
		ddshift := int(e.curve_shift)
		return abs32(e.cdx) >> 1 >= abs32(e.cddx) >> ddshift
			&& abs32(e.cdy) >> 1 >= abs32(e.cddy) >> ddshift
			&& (e.cdy - (e.cddy >> ddshift)) >> int(e.cubic_dshift) >= fixed1
	} else if e.curve_count > 0 {
		return abs32(e.qdx) >> 1 >= abs32(e.qddx) && abs32(e.qdy) >> 1 >= abs32(e.qddy)
			&& (e.qdy - e.qddy) >> int(e.curve_shift) >= fixed1
	}
	return abs32(sat_sub32(next.dx, e.dx)) <= fixed1 && next.lower_y - next.upper_y >= fixed1
}

fn sat_sub32(a i32, b i32) i32 {
	diff := i64(a) - i64(b)
	return if diff > max_i32 {
		max_i32
	} else if diff < min_i32 {
		min_i32
	} else {
		i32(diff)
	}
}

fn (l &EdgeList) is_smooth_enough(left int, rite int, curr_in int, stop_y int) bool {
	mut curr := curr_in
	if l.edges[curr].upper_y >= left_shift(i32(stop_y), 16) {
		return false
	}
	if l.edges[left].lower_y + fixed1 < l.edges[rite].lower_y {
		return is_smooth_enough_edge(&l.edges[left], &l.edges[curr])
	} else if l.edges[left].lower_y > l.edges[rite].lower_y + fixed1 {
		return is_smooth_enough_edge(&l.edges[rite], &l.edges[curr])
	}
	mut next_curr := l.edges[curr].next
	if l.edges[next_curr].upper_y >= i32(stop_y) << 16 {
		return false
	}
	if l.edges[next_curr].upper_x < l.edges[curr].upper_x {
		curr, next_curr = next_curr, curr
	}
	return is_smooth_enough_edge(&l.edges[left], &l.edges[curr])
		&& is_smooth_enough_edge(&l.edges[rite], &l.edges[next_curr])
}

fn (mut l EdgeList) aaa_walk_convex_edges(mut blitter AdditiveBlitter, stop_y int, left_bound i32, rite_bound i32, is_using_mask bool) {
	mut left_e := l.edges[l.head].next
	mut rite_e := l.edges[left_e].next
	mut curr_e := l.edges[rite_e].next
	mut y := if l.edges[left_e].upper_y > l.edges[rite_e].upper_y {
		l.edges[left_e].upper_y
	} else {
		l.edges[rite_e].upper_y
	}
	walk: for {
		for l.edges[left_e].lower_y <= y {
			if !l.edges[left_e].update() {
				if fixed_floor_to_int(l.edges[curr_e].upper_y) >= stop_y {
					break walk
				}
				left_e = curr_e
				curr_e = l.edges[curr_e].next
			}
		}
		for l.edges[rite_e].lower_y <= y {
			if !l.edges[rite_e].update() {
				if fixed_floor_to_int(l.edges[curr_e].upper_y) >= stop_y {
					break walk
				}
				rite_e = curr_e
				curr_e = l.edges[curr_e].next
			}
		}
		if fixed_floor_to_int(y) >= stop_y {
			break
		}
		l.edges[left_e].go_y(y)
		l.edges[rite_e].go_y(y)
		if l.edges[left_e].x > l.edges[rite_e].x
			|| (l.edges[left_e].x == l.edges[rite_e].x && l.edges[left_e].dx > l.edges[rite_e].dx) {
			left_e, rite_e = rite_e, left_e
		}
		mut local_bot_fixed := if l.edges[left_e].lower_y < l.edges[rite_e].lower_y {
			l.edges[left_e].lower_y
		} else {
			l.edges[rite_e].lower_y
		}
		if l.is_smooth_enough(left_e, rite_e, curr_e, stop_y) {
			local_bot_fixed = fixed_ceil_to_fixed(local_bot_fixed)
		}
		stop_fixed := int_to_fixed(stop_y)
		if stop_fixed < local_bot_fixed {
			local_bot_fixed = stop_fixed
		}
		mut left := if left_bound > l.edges[left_e].x { left_bound } else { l.edges[left_e].x }
		d_left := l.edges[left_e].dx
		mut rite := if rite_bound < l.edges[rite_e].x { rite_bound } else { l.edges[rite_e].x }
		d_rite := l.edges[rite_e].dx
		if (d_left | d_rite) == 0 {
			full_left := fixed_ceil_to_int(left)
			full_rite := fixed_floor_to_int(rite)
			partial_left := int_to_fixed(full_left) - left
			partial_rite := rite - int_to_fixed(full_rite)
			full_top := fixed_ceil_to_int(y)
			full_bot := fixed_floor_to_int(local_bot_fixed)
			mut partial_top := int_to_fixed(full_top) - y
			mut partial_bot := local_bot_fixed - int_to_fixed(full_bot)
			if full_top > full_bot {
				partial_top -= (fixed1 - partial_bot)
				partial_bot = 0
			}
			if full_rite >= full_left {
				if partial_top > 0 {
					if partial_left > 0 {
						blitter.blit_anti_h1(full_left - 1, full_top - 1, fixed_to_alpha(fixed_mul(partial_top,
							partial_left)))
					}
					blitter.blit_anti_hw(full_left, full_top - 1, full_rite - full_left,
						fixed_to_alpha(partial_top))
					if partial_rite > 0 {
						blitter.blit_anti_h1(full_rite, full_top - 1, fixed_to_alpha(fixed_mul(partial_top,
							partial_rite)))
					}
					blitter.flush_if_y_changed(y, y + partial_top)
				}
				if full_bot > full_top && (full_rite > full_left
					|| fixed_to_alpha(partial_left) > 0 || fixed_to_alpha(partial_rite) > 0) {
					blitter.real_blit_anti_rect(full_left - 1, full_top, full_rite - full_left,
						full_bot - full_top, fixed_to_alpha(partial_left), fixed_to_alpha(partial_rite))
				}
				if partial_bot > 0 {
					if partial_left > 0 {
						blitter.blit_anti_h1(full_left - 1, full_bot, fixed_to_alpha(fixed_mul(partial_bot,
							partial_left)))
					}
					blitter.blit_anti_hw(full_left, full_bot, full_rite - full_left, fixed_to_alpha(partial_bot))
					if partial_rite > 0 {
						blitter.blit_anti_h1(full_rite, full_bot, fixed_to_alpha(fixed_mul(partial_bot,
							partial_rite)))
					}
				}
			} else {
				width := rite - left
				if width > 0 {
					if partial_top > 0 {
						blitter.blit_anti_hw(full_left - 1, full_top - 1, 1, fixed_to_alpha(fixed_mul(partial_top,
							width)))
						blitter.flush_if_y_changed(y, y + partial_top)
					}
					if full_bot > full_top {
						blitter.real_blit_v(full_left - 1, full_top, full_bot - full_top,
							fixed_to_alpha(width))
					}
					if partial_bot > 0 {
						blitter.blit_anti_hw(full_left - 1, full_bot, 1, fixed_to_alpha(fixed_mul(partial_bot,
							width)))
					}
				}
			}
			y = local_bot_fixed
		} else {
			snap_digit := fixed1 >> 4
			snap_half := snap_digit >> 1
			snap_mask := i32(-1 ^ (snap_digit - 1))
			left += snap_half
			rite += snap_half
			mut count := fixed_ceil_to_int(local_bot_fixed) - fixed_floor_to_int(y)
			mut mask_row := if is_using_mask { blitter.get_row(int(y >> 16)) } else { no_mask_row }
			if count > 1 {
				if i32(u32(y) & 0xffff0000) != y {
					count--
					next_y := fixed_ceil_to_fixed(y + 1)
					d_y := next_y - y
					next_left := left + fixed_mul(d_left, d_y)
					next_rite := rite + fixed_mul(d_rite, d_y)
					blit_trapezoid_row(mut blitter, int(y >> 16), left & snap_mask, rite & snap_mask,
						next_left & snap_mask, next_rite & snap_mask, l.edges[left_e].dy,
						l.edges[rite_e].dy, get_partial_alpha_fixed(255, d_y), mask_row,
						false)
					blitter.flush_if_y_changed(y, next_y)
					left = next_left
					rite = next_rite
					y = next_y
				}
				for count > 1 {
					count--
					if is_using_mask {
						mask_row = blitter.get_row(int(y >> 16))
					}
					next_y := y + fixed1
					next_left := left + d_left
					next_rite := rite + d_rite
					blit_trapezoid_row(mut blitter, int(y >> 16), left & snap_mask, rite & snap_mask,
						next_left & snap_mask, next_rite & snap_mask, l.edges[left_e].dy,
						l.edges[rite_e].dy, 255, mask_row, false)
					blitter.flush_if_y_changed(y, next_y)
					left = next_left
					rite = next_rite
					y = next_y
				}
			}
			if is_using_mask {
				mask_row = blitter.get_row(int(y >> 16))
			}
			d_y := local_bot_fixed - y
			mut next_left := left + fixed_mul(d_left, d_y)
			if next_left < left_bound + snap_half {
				next_left = left_bound + snap_half
			}
			mut next_rite := rite + fixed_mul(d_rite, d_y)
			if next_rite > rite_bound + snap_half {
				next_rite = rite_bound + snap_half
			}
			blit_trapezoid_row(mut blitter, int(y >> 16), left & snap_mask, rite & snap_mask,
				next_left & snap_mask, next_rite & snap_mask, l.edges[left_e].dy, l.edges[rite_e].dy,
				get_partial_alpha_fixed(255, d_y), mask_row, false)
			blitter.flush_if_y_changed(y, local_bot_fixed)
			left = next_left
			rite = next_rite
			y = local_bot_fixed
			left -= snap_half
			rite -= snap_half
		}
		l.edges[left_e].x = left
		l.edges[rite_e].x = rite
		l.edges[left_e].y = y
		l.edges[rite_e].y = y
	}
}

@[inline]
fn update_next_next_y(y i32, next_y i32, next_next_y i32) i32 {
	return if y > next_y && y < next_next_y { y } else { next_next_y }
}

fn (l &EdgeList) check_intersection(i int, next_y i32, next_next_y i32) i32 {
	e := &l.edges[i]
	prev := &l.edges[e.prev]
	if prev.prev >= 0 && prev.x + prev.dx > e.x + e.dx {
		return next_y + (fixed1 >> default_accuracy)
	}
	return next_next_y
}

fn (l &EdgeList) check_intersection_fwd(i int, next_y i32, next_next_y i32) i32 {
	e := &l.edges[i]
	next := &l.edges[e.next]
	if next.next >= 0 && e.x + e.dx > next.x + next.dx {
		return next_y + (fixed1 >> default_accuracy)
	}
	return next_next_y
}

fn (mut l EdgeList) insert_new_edges(new_edge_in int, y i32, next_next_y_in i32) i32 {
	mut new_edge := new_edge_in
	mut next_next_y := next_next_y_in
	if l.edges[new_edge].upper_y > y {
		return update_next_next_y(l.edges[new_edge].upper_y, y, next_next_y)
	}
	prev := l.edges[new_edge].prev
	if l.edges[prev].x <= l.edges[new_edge].x {
		for l.edges[new_edge].upper_y <= y {
			next_next_y = l.check_intersection(new_edge, y, next_next_y)
			next_next_y = update_next_next_y(l.edges[new_edge].lower_y, y, next_next_y)
			new_edge = l.edges[new_edge].next
		}
		return update_next_next_y(l.edges[new_edge].upper_y, y, next_next_y)
	}
	mut start := l.backward_insert_start(prev, l.edges[new_edge].x)
	for {
		next := l.edges[new_edge].next
		mut already := false
		for {
			if l.edges[start].next == new_edge {
				already = true
				break
			}
			after := l.edges[start].next
			if l.edges[after].x >= l.edges[new_edge].x {
				break
			}
			start = after
		}
		if !already {
			l.remove_edge(new_edge)
			l.insert_edge_after(new_edge, start)
		}
		next_next_y = l.check_intersection(new_edge, y, next_next_y)
		next_next_y = l.check_intersection_fwd(new_edge, y, next_next_y)
		next_next_y = update_next_next_y(l.edges[new_edge].lower_y, y, next_next_y)
		start = new_edge
		new_edge = next
		if l.edges[new_edge].upper_y > y {
			break
		}
	}
	return update_next_next_y(l.edges[new_edge].upper_y, y, next_next_y)
}

fn (l &EdgeList) edges_too_close(prev int, next int, lower_y i32) bool {
	if next < 0 || prev < 0 {
		return false
	}
	n := &l.edges[next]
	p := &l.edges[prev]
	return n.upper_y < lower_y && p.x + fixed1 >= n.x - abs32(n.dx)
}

@[inline]
fn edges_too_close_rite(prev_rite int, ul i32, ll i32) bool {
	return prev_rite > fixed_floor_to_int(ul) || prev_rite > fixed_floor_to_int(ll)
}

fn (mut l EdgeList) aaa_walk_edges(fill_type PathFillType, mut blitter AdditiveBlitter, start_y_in int, stop_y int, left_clip i32, right_clip i32, is_using_mask bool, force_rle bool, skip_intersect bool) {
	mut start_y := start_y_in
	l.edges[l.head].x = left_clip
	l.edges[l.head].upper_x = left_clip
	l.edges[l.tail].x = right_clip
	l.edges[l.tail].upper_x = right_clip
	first := l.edges[l.head].next
	mut y := if l.edges[first].upper_y > int_to_fixed(start_y) {
		l.edges[first].upper_y
	} else {
		int_to_fixed(start_y)
	}
	mut next_next_y := max_i32
	{
		mut edge := first
		for l.edges[edge].upper_y <= y {
			l.edges[edge].go_y(y)
			next_next_y = update_next_next_y(l.edges[edge].lower_y, y, next_next_y)
			edge = l.edges[edge].next
		}
		next_next_y = update_next_next_y(l.edges[edge].upper_y, y, next_next_y)
	}
	winding_mask := if fill_type == .even_odd || fill_type == .inverse_even_odd { 1 } else { -1 }
	is_inverse := fill_type == .inverse_winding || fill_type == .inverse_even_odd
	if is_inverse && int_to_fixed(start_y) != y {
		width := fixed_floor_to_int(right_clip - left_clip)
		if fixed_floor_to_int(y) != start_y {
			blitter.real_blit_rect(fixed_floor_to_int(left_clip), start_y, width, fixed_floor_to_int(y) - start_y)
			start_y = fixed_floor_to_int(y)
		}
		mask_row := if is_using_mask { blitter.get_row(start_y) } else { no_mask_row }
		blit_full_alpha(mut blitter, start_y, fixed_floor_to_int(left_clip), width, fixed_to_alpha(y - int_to_fixed(start_y)),
			mask_row, false)
	}
	for {
		mut w := 0
		mut in_interval := is_inverse
		mut prev_x := l.edges[l.head].x
		ceil_next := fixed_ceil_to_fixed(y + 1)
		mut next_y := if next_next_y < ceil_next { next_next_y } else { ceil_next }
		mut curr_e := l.edges[l.head].next
		mut left_e := l.head
		mut left := left_clip
		mut left_dy := i32(0)
		mut prev_rite := fixed_floor_to_int(left_clip)
		next_next_y = max_i32
		mut y_shift := 0
		if (next_y - y) & (fixed1 >> 2) != 0 {
			y_shift = 2
			next_y = y + (fixed1 >> 2)
		} else if (next_y - y) & (fixed1 >> 1) != 0 {
			y_shift = 1
		}
		full_alpha := fixed_to_alpha(next_y - y)
		mask_row := if is_using_mask { blitter.get_row(fixed_floor_to_int(y)) } else { no_mask_row }
		no_real_blitter := force_rle
		for l.edges[curr_e].upper_y <= y {
			w += int(l.edges[curr_e].winding)
			prev_in_interval := in_interval
			in_interval = ((w & winding_mask) == 0) == is_inverse
			is_left := in_interval && !prev_in_interval
			is_rite := !in_interval && prev_in_interval
			if is_rite {
				mut rite := l.edges[curr_e].x
				l.edges[curr_e].go_y_shift(next_y, y_shift)
				next_left := if left_clip > l.edges[left_e].x {
					left_clip
				} else {
					l.edges[left_e].x
				}
				if right_clip < rite {
					rite = right_clip
				}
				next_rite := if right_clip < l.edges[curr_e].x {
					right_clip
				} else {
					l.edges[curr_e].x
				}
				too_close := full_alpha == 255 && (edges_too_close_rite(prev_rite, left, l.edges[left_e].x)
					|| l.edges_too_close(curr_e, l.edges[curr_e].next, next_y))
				blit_trapezoid_row(mut blitter, int(y >> 16), left, rite, next_left, next_rite,
					left_dy, l.edges[curr_e].dy, full_alpha, mask_row, no_real_blitter || too_close)
				max_rite := if rite > l.edges[curr_e].x { rite } else { l.edges[curr_e].x }
				prev_rite = fixed_ceil_to_int(max_rite)
			} else {
				if is_left {
					left = if l.edges[curr_e].x > left_clip { l.edges[curr_e].x } else { left_clip }
					left_dy = l.edges[curr_e].dy
					left_e = curr_e
				}
				l.edges[curr_e].go_y_shift(next_y, y_shift)
			}
			next := l.edges[curr_e].next
			for l.edges[curr_e].lower_y <= next_y {
				if l.edges[curr_e].curve_count < 0 {
					l.edges[curr_e].keep_continuous()
					if !l.edges[curr_e].update_cubic() {
						break
					}
				} else if l.edges[curr_e].curve_count > 0 {
					l.edges[curr_e].keep_continuous()
					if !l.edges[curr_e].update_quadratic() {
						break
					}
				} else {
					break
				}
			}
			if l.edges[curr_e].lower_y <= next_y {
				l.remove_edge(curr_e)
			} else {
				next_next_y = update_next_next_y(l.edges[curr_e].lower_y, next_y, next_next_y)
				new_x := l.edges[curr_e].x
				if new_x < prev_x {
					l.backward_insert_edge_based_on_x(curr_e)
				} else {
					prev_x = new_x
				}
				if !skip_intersect {
					next_next_y = l.check_intersection(curr_e, next_y, next_next_y)
				}
			}
			curr_e = next
		}
		if in_interval {
			left_e_x := l.edges[left_e].x
			next_left := if left_clip > left_e_x { left_clip } else { left_e_x }
			too_close := full_alpha == 255 && l.edges_too_close(l.edges[left_e].prev, left_e,
				next_y)
			blit_trapezoid_row(mut blitter, int(y >> 16), left, right_clip, next_left, right_clip,
				left_dy, 0, full_alpha, mask_row, no_real_blitter || too_close)
		}
		if force_rle {
			blitter.flush_if_y_changed(y, next_y)
		}
		y = next_y
		if y >= int_to_fixed(stop_y) {
			break
		}
		next_next_y = l.insert_new_edges(curr_e, y, next_next_y)
	}
}

fn aaa_fill_path(path Path, convex bool, clip_rect IRect, mut blitter AdditiveBlitter, start_y_in int, stop_y_in int, contained bool, is_using_mask bool, force_rle bool) bool {
	clip_f := Rect{f32(clip_rect.left), f32(clip_rect.top), f32(clip_rect.right), f32(clip_rect.bottom)}
	mut builder := build_edges(path, if contained { ?Rect(none) } else { ?Rect(clip_f) },
		convex)
	mut start_y := start_y_in
	mut stop_y := stop_y_in
	count := builder.list.len
	if count == 0 {
		if path.is_inverse_fill() {
			mut rect := clip_rect
			if rect.top < start_y {
				rect.top = start_y
			}
			if rect.bottom > stop_y {
				rect.bottom = stop_y
			}
			if !rect.is_empty() {
				blitter.real_blit_rect(rect.left, rect.top, rect.width(), rect.height())
			}
		}
		return true
	}
	mut list := EdgeList{
		edges: builder.edges
	}
	mut order := builder.list.clone()
	sort_edge_indices(list.edges, mut order)
	for i in 1 .. count {
		list.edges[order[i - 1]].next = order[i]
		list.edges[order[i]].prev = order[i - 1]
	}
	list.head = list.edges.len
	list.tail = list.edges.len + 1
	list.edges << Edge{
		prev:    -1
		next:    order[0]
		upper_y: min_i32
		lower_y: min_i32
		x:       min_i32
		dx:      0
		dy:      max_i32
		upper_x: min_i32
	}
	list.edges << Edge{
		prev:    order[count - 1]
		next:    -1
		upper_y: max_i32
		lower_y: max_i32
		x:       max_i32
		dx:      0
		dy:      max_i32
		upper_x: max_i32
	}
	list.edges[order[0]].prev = list.head
	list.edges[order[count - 1]].next = list.tail
	if !contained && start_y < clip_rect.top {
		start_y = clip_rect.top
	}
	if !contained && stop_y > clip_rect.bottom {
		stop_y = clip_rect.bottom
	}
	mut left_bound := int_to_fixed(clip_rect.left)
	mut right_bound := int_to_fixed(clip_rect.right)
	if is_using_mask {
		bounds := path.bounds() or { Rect{} }
		ir := round_out(bounds)
		if int_to_fixed(ir.left) > left_bound {
			left_bound = int_to_fixed(ir.left)
		}
		if int_to_fixed(ir.right) < right_bound {
			right_bound = int_to_fixed(ir.right)
		}
	}
	if !path.is_inverse_fill() && convex && count >= 2 {
		list.aaa_walk_convex_edges(mut blitter, stop_y, left_bound, right_bound,
			is_using_mask)
	} else {
		skip_intersect := path.points.len > (stop_y - start_y) * 2
		list.aaa_walk_edges(path.fill_type, mut blitter, start_y, stop_y, left_bound, right_bound,
			is_using_mask, force_rle, skip_intersect)
	}
	return true
}

// SkScan::AAAFillPath().
fn aaa_fill_path_entry(path Path, convex bool, mut real Blitter, ir IRect, clip_bounds IRect, force_rle bool) bool {
	contained := clip_bounds.contains(ir)
	is_inverse := path.is_inverse_fill()
	if mask_can_handle_rect(ir) && !is_inverse && !force_rle {
		if rect := path.is_rect() {
			clip_f := Rect{f32(clip_bounds.left), f32(clip_bounds.top), f32(clip_bounds.right), f32(clip_bounds.bottom)}
			clipped := intersect_rect(rect, clip_f) or { return true }
			if round_out(clipped).width() >= 3 {
				blit_fat_anti_rect(mut real, clipped)
				return true
			}
		}
		mut additive := new_mask_blitter(real, ir, clip_bounds)
		if !aaa_fill_path(path, convex, clip_bounds, mut additive, ir.top, ir.bottom, contained,
			true, false) {
			return false
		}
		additive.finish()
	} else {
		mut additive := new_rle_blitter(real, ir, clip_bounds, is_inverse, is_inverse || !convex)
		if !aaa_fill_path(path, convex, clip_bounds, mut additive, ir.top, ir.bottom, contained,
			false, force_rle) {
			return false
		}
		additive.finish()
	}
	return true
}

// SkRect::intersect().
fn intersect_rect(a Rect, b Rect) ?Rect {
	left := if a.left > b.left { a.left } else { b.left }
	top := if a.top > b.top { a.top } else { b.top }
	right := if a.right < b.right { a.right } else { b.right }
	bottom := if a.bottom < b.bottom { a.bottom } else { b.bottom }
	if !(left < right && top < bottom) {
		return none
	}
	return Rect{left, top, right, bottom}
}

// SkScan::AntiFillPath() with a rectangular device clip. Returns false,
// without blitting, for the cases not yet ported: inverse fills and paths too
// large for anti-aliasing.
pub fn anti_fill_path(path Path, clip IRect, mut blitter Blitter) bool {
	return anti_fill_path_convexity(path, false, clip, mut blitter)
}

// anti_fill_path_convexity is anti_fill_path() for a path whose builder
// already knows it is convex (SkPathPriv::Raw() keeps a known convexity
// instead of computing it).
fn anti_fill_path_convexity(path Path, known_convex bool, clip IRect, mut blitter Blitter) bool {
	rc := new_raster_clip(clip)
	return anti_fill_path_clip(path, known_convex, &rc, mut blitter)
}

// anti_fill_path_clip is Draw::drawDevPath()'s fill through a raster clip:
// SkScan::AntiFillPath(raw, rasterClip, blitter), which fills inside an
// SkAAClip through SkAAClipBlitter and run-length coverage.
fn anti_fill_path_clip(path Path, known_convex bool, rc &RasterClip, mut blitter Blitter) bool {
	return anti_fill_path_convex(path, known_convex || path.convexity() != .concave, rc, mut
		blitter)
}

// anti_fill_path_convex is anti_fill_path_clip() for a path whose convexity
// is already resolved, as an SkPathRaw carries it.
fn anti_fill_path_convex(path Path, convex bool, rc &RasterClip, mut blitter Blitter) bool {
	if path.is_inverse_fill() {
		return false
	}
	bounds := path.bounds() or { return true }
	if path.verbs.len == 0 {
		return true
	}
	limit := f32(3.4028235e38) * f32(0.25)
	if !(bounds.left >= -limit && bounds.top >= -limit && bounds.right <= limit
		&& bounds.bottom <= limit) {
		return true
	}
	if rc.is_empty {
		return true
	}
	if rc.is_bw {
		return anti_fill_region(path, convex, rc.rect, mut blitter, false)
	}
	mut aa := new_aaclip_blitter(blitter, &rc.aa)
	return anti_fill_region(path, convex, rc.aa.bounds, mut aa, true)
}

// SkScan::AntiFillPath(raw, region, blitter, forceRLE) for a rect region.
fn anti_fill_region(path Path, convex bool, clip_in IRect, mut blitter Blitter, force_rle bool) bool {
	if path.is_inverse_fill() {
		return false
	}
	bounds := path.bounds() or { return true }
	if clip_in.is_empty() {
		return true
	}
	// safeRoundOut()
	mut ir := round_out(bounds)
	sat_limit := max_i32 >> 2
	ir = ir.intersect(IRect{-sat_limit, -sat_limit, sat_limit, sat_limit}) or { ir }
	if ir.is_empty() {
		return true
	}
	clipped := ir.intersect(clip_in) or { return true }
	// Bounds that overflow 16 bits once supersampled are filled without
	// anti-aliasing.
	if overflows_short_shift(clipped.left, 2) || overflows_short_shift(clipped.right, 2)
		|| overflows_short_shift(clipped.top, 2) || overflows_short_shift(clipped.bottom, 2) {
		fill_path_region(path, convex, clip_in, mut blitter)
		return true
	}
	// The runs' 16-bit indices limit the clip to 32767.
	mut clip := clip_in
	if clip.right > 32767 || clip.bottom > 32767 {
		clip = clip.intersect(IRect{0, 0, 32767, 32767}) or { IRect{} }
	}
	// SkScanClipper: nothing outside the clip, and a wrapper only when
	// clipped horizontally.
	if !irect_intersects(clip, ir) {
		return true
	}
	if clip.contains(ir) || !(clip.left > ir.left || clip.right < ir.right) {
		return aaa_fill_path_entry(path, convex, mut blitter, ir, clip, force_rle)
	}
	mut wrapper := RectClipBlitter{
		clip:  clip
		inner: blitter
	}
	return aaa_fill_path_entry(path, convex, mut wrapper, ir, clip, force_rle)
}

fn overflows_short_shift(value int, shift int) bool {
	s := 16 + shift
	return (i32(u32(value) << u32(s)) >> s) != value
}
