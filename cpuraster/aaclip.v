module cpuraster

import math

// Anti-aliased clips as LibWeb Skia (google/skia ee20d565) keeps them for a
// raster canvas: SkRasterClip holds a hard-edged rect or an SkAAClip, a
// run-length coverage mask built by filling the clip path with the analytic
// AA scan converter. Draws inside an SkAAClip go through SkAAClipBlitter,
// which scales their coverage by the clip's.

// SkAAClip row: [count, alpha] pairs covering the clip width. y is the last
// scanline the row covers, relative to the clip's top (YOffset::fY).
struct AAClipRow {
mut:
	y    int
	data []u8
}

// SkAAClip: empty when it has no rows (a null fRunHead).
struct AAClip {
mut:
	bounds IRect
	rows   []AAClipRow
}

@[inline]
fn (c &AAClip) is_empty() bool {
	return c.rows.len == 0
}

fn (mut c AAClip) set_empty() bool {
	c.bounds = IRect{}
	c.rows = []AAClipRow{}
	return false
}

// Runs of at most 255 pixels covering width with alpha.
fn append_aa_runs(mut data []u8, alpha u8, count_in int) {
	mut count := count_in
	for {
		n := if count > 255 { 255 } else { count }
		data << u8(n)
		data << alpha
		count -= n
		if count <= 0 {
			break
		}
	}
}

// SkAAClip::setRect() (RunHead::AllocRect()).
fn (mut c AAClip) set_rect(bounds IRect) bool {
	if bounds.is_empty() {
		return c.set_empty()
	}
	mut data := []u8{}
	mut width := bounds.width()
	for width > 0 {
		n := if width < 255 { width } else { 255 }
		data << u8(n)
		data << 0xff
		width -= n
	}
	c.bounds = bounds
	c.rows = [AAClipRow{bounds.height() - 1, data}]
	return true
}

// SkAAClip::isRect(), including its comparison of the relative row y with
// the absolute bottom.
fn (c &AAClip) is_rect() bool {
	if c.is_empty() || c.rows.len != 1 {
		return false
	}
	if c.rows[0].y != c.bounds.bottom - 1 {
		return false
	}
	row := c.rows[0].data
	mut width := c.bounds.width()
	mut i := 0
	for {
		if row[i + 1] != 0xff {
			return false
		}
		width -= int(row[i])
		i += 2
		if width <= 0 {
			break
		}
	}
	return true
}

// SkAAClip::findRow(): the row covering y and the last absolute y it covers.
fn (c &AAClip) find_row(y_in int) (int, int) {
	y := y_in - c.bounds.top
	mut index := 0
	for c.rows[index].y < y {
		index++
	}
	return index, c.bounds.top + c.rows[index].y
}

// SkAAClip::findX(): the pair covering x in row data and how many pixels of
// it remain from x.
fn (c &AAClip) find_x(data []u8, x_in int) (int, int) {
	mut x := x_in - c.bounds.left
	mut i := 0
	for {
		n := int(data[i])
		if x < n {
			return i, n - x
		}
		i += 2
		x -= n
	}
	return i, 0
}

// SkAAClip::quickContains(): whether the clip is fully opaque over the rect.
fn (c &AAClip) quick_contains(left int, top int, right int, bottom int) bool {
	if c.is_empty() {
		return false
	}
	if !c.bounds.contains(IRect{left, top, right, bottom}) {
		return false
	}
	row, last_y := c.find_row(top)
	if last_y < bottom {
		return false
	}
	data := c.rows[row].data
	mut i, mut count := c.find_x(data, left)
	mut rect_width := right - left
	for data[i + 1] == 0xff {
		if count >= rect_width {
			return true
		}
		rect_width -= count
		i += 2
		count = int(data[i])
	}
	return false
}

// count_left_right_zeros(): the transparent pixels at each end of a row,
// width for both when the row is fully transparent.
fn count_left_right_zeros(row []u8, width_in int) (int, int) {
	mut width := width_in
	mut i := 0
	mut zeros := 0
	for {
		if row[i + 1] != 0 {
			break
		}
		n := int(row[i])
		zeros += n
		i += 2
		width -= n
		if width <= 0 {
			break
		}
	}
	left := zeros
	if width == 0 {
		return left, left
	}
	zeros = 0
	for width > 0 {
		n := int(row[i])
		if row[i + 1] == 0 {
			zeros += n
		} else {
			zeros = 0
		}
		i += 2
		width -= n
	}
	return left, zeros
}

// trim_row_left_right(): the row without left_z and rite_z transparent
// pixels at its ends, the partial runs at each end shortened in place.
fn trim_row_left_right(row []u8, width int, left_z_in int, rite_z_in int) []u8 {
	mut out := row.clone()
	mut left_z := left_z_in
	mut start := 0
	for left_z > 0 {
		n := int(out[start])
		start += 2
		if n > left_z {
			out[start - 2] = u8(n - left_z)
			start -= 2
			break
		}
		left_z -= n
	}
	mut end := start
	mut remaining := width - left_z_in
	for remaining > 0 {
		remaining -= int(out[end])
		end += 2
	}
	mut rite_z := rite_z_in
	for rite_z > 0 {
		end -= 2
		n := int(out[end])
		if n > rite_z {
			out[end] = u8(n - rite_z)
			end += 2
			break
		}
		rite_z -= n
	}
	return out[start..end].clone()
}

// SkAAClip::trimLeftRight().
fn (mut c AAClip) trim_left_right() bool {
	if c.is_empty() {
		return false
	}
	width := c.bounds.width()
	mut left_zeros := width
	mut rite_zeros := width
	for row in c.rows {
		l, r := count_left_right_zeros(row.data, width)
		if l < left_zeros {
			left_zeros = l
		}
		if r < rite_zeros {
			rite_zeros = r
		}
		if left_zeros | rite_zeros == 0 {
			return true
		}
	}
	if width == left_zeros {
		return c.set_empty()
	}
	c.bounds.left += left_zeros
	c.bounds.right -= rite_zeros
	for mut row in c.rows {
		row.data = trim_row_left_right(row.data, width, left_zeros, rite_zeros)
	}
	return true
}

fn row_is_all_zeros(row []u8, width_in int) bool {
	mut width := width_in
	mut i := 0
	for {
		if row[i + 1] != 0 {
			return false
		}
		width -= int(row[i])
		i += 2
		if width <= 0 {
			break
		}
	}
	return true
}

// SkAAClip::trimTopBottom().
fn (mut c AAClip) trim_top_bottom() bool {
	if c.is_empty() {
		return false
	}
	width := c.bounds.width()
	mut skip := 0
	for skip < c.rows.len && row_is_all_zeros(c.rows[skip].data, width) {
		skip++
	}
	if skip == c.rows.len {
		return c.set_empty()
	}
	if skip > 0 {
		dy := c.rows[skip - 1].y + 1
		mut kept := c.rows[skip..].clone()
		for mut row in kept {
			row.y -= dy
		}
		c.rows = kept
		c.bounds.top += dy
	}
	mut last := c.rows.len - 1
	for row_is_all_zeros(c.rows[last].data, width) {
		last--
	}
	if last < c.rows.len - 1 {
		c.bounds.bottom = c.bounds.top + c.rows[last].y + 1
		c.rows = c.rows[..last + 1].clone()
	}
	return true
}

// SkAAClip::trimBounds().
fn (mut c AAClip) trim_bounds() bool {
	if c.is_empty() {
		return false
	}
	c.bounds.bottom = c.bounds.top + c.rows.last().y + 1
	return c.trim_top_bottom() && c.trim_left_right()
}

// SkAAClip::Builder's row under construction.
struct AAClipBuilderRow {
mut:
	y     int
	width int
	data  []u8
}

// SkAAClip::Builder.
struct AAClipBuilder {
mut:
	bounds IRect
	rows   []AAClipBuilderRow
	curr   int = -1
	prev_y int = -1
	width  int
	min_y  int
}

fn new_aaclip_builder(bounds IRect) AAClipBuilder {
	return AAClipBuilder{
		bounds: bounds
		width:  bounds.width()
		min_y:  bounds.top
	}
}

fn (mut b AAClipBuilder) flush_row_h(index int) {
	if b.rows[index].width < b.width {
		append_aa_runs(mut b.rows[index].data, 0, b.width - b.rows[index].width)
		b.rows[index].width = b.width
	}
}

// flushRow(): finishes the last row, merging it into the previous one when
// their runs are equal, and returns the next row to fill (or -1).
fn (mut b AAClipBuilder) flush_row(ready_for_another bool) int {
	count := b.rows.len
	if count > 0 {
		b.flush_row_h(count - 1)
	}
	if count > 1 {
		if b.rows[count - 2].data == b.rows[count - 1].data {
			b.rows[count - 2].y = b.rows[count - 1].y
			if ready_for_another {
				b.rows[count - 1].data.clear()
				return count - 1
			}
			b.rows.delete(count - 1)
			return -1
		}
	}
	if ready_for_another {
		b.rows << AAClipBuilderRow{}
		return b.rows.len - 1
	}
	return -1
}

fn (mut b AAClipBuilder) add_run(x_in int, y_in int, alpha u8, count int) {
	x := x_in - b.bounds.left
	y := y_in - b.bounds.top
	mut row := b.curr
	if y != b.prev_y {
		b.prev_y = y
		row = b.flush_row(true)
		b.rows[row].y = y
		b.rows[row].width = 0
		b.curr = row
	}
	gap := x - b.rows[row].width
	if gap != 0 {
		append_aa_runs(mut b.rows[row].data, 0, gap)
		b.rows[row].width += gap
	}
	append_aa_runs(mut b.rows[row].data, alpha, count)
	b.rows[row].width += count
}

fn (mut b AAClipBuilder) add_column(x int, y int, alpha u8, height int) {
	b.add_run(x, y, alpha, 1)
	b.flush_row_h(b.curr)
	b.rows[b.curr].y = y - b.bounds.top + height - 1
}

fn (mut b AAClipBuilder) add_rect_run(x int, y int, width int, height int) {
	b.add_run(x, y, 0xff, width)
	b.flush_row_h(b.curr)
	b.rows[b.curr].y = y - b.bounds.top + height - 1
}

fn (mut b AAClipBuilder) add_anti_rect_run(x_in int, y int, width_in int, height int, left_alpha u8, right_alpha u8) {
	mut x := x_in
	mut width := width_in
	if left_alpha == 0xff {
		width++
	} else if left_alpha > 0 {
		b.add_run(x, y, left_alpha, 1)
		x++
	} else {
		x++
	}
	if right_alpha == 0xff {
		width++
	}
	if width > 0 {
		b.add_run(x, y, 0xff, width)
	}
	if right_alpha > 0 && right_alpha < 255 {
		b.add_run(x + width, y, right_alpha, 1)
	}
	if b.curr >= 0 {
		b.flush_row_h(b.curr)
		b.rows[b.curr].y = y - b.bounds.top + height - 1
	}
}

// finish(): packs the rows into target and trims its bounds.
fn (mut b AAClipBuilder) finish(mut target AAClip) bool {
	b.flush_row(false)
	mut data_size := 0
	for row in b.rows {
		data_size += row.data.len
	}
	if data_size == 0 {
		return target.set_empty()
	}
	adjust_y := b.min_y - b.bounds.top
	b.bounds.top = b.min_y
	mut rows := []AAClipRow{cap: b.rows.len}
	for row in b.rows {
		rows << AAClipRow{row.y - adjust_y, row.data}
	}
	target.bounds = b.bounds
	target.rows = rows
	return target.trim_bounds()
}

// SkAAClip::Builder::Blitter: records the clip path's coverage in scanline
// order.
struct AAClipBuilderBlitter {
mut:
	builder &AAClipBuilder
	left    int
	right   int
	min_y   int = max_i32
	last_y  int = -max_i32
}

fn (mut b AAClipBuilderBlitter) check_for_y_gap(y int) {
	if b.last_y > -max_i32 {
		gap := y - b.last_y
		if gap > 1 {
			b.builder.add_run(b.left, y - 1, 0, b.right - b.left)
		}
	}
	b.last_y = y
}

@[inline]
fn (mut b AAClipBuilderBlitter) record_min_y(y int) {
	if y < b.min_y {
		b.min_y = y
	}
}

fn (mut b AAClipBuilderBlitter) blit_h(x int, y int, width int) {
	b.record_min_y(y)
	b.check_for_y_gap(y)
	b.builder.add_run(x, y, 0xff, width)
}

fn (mut b AAClipBuilderBlitter) blit_anti_h(x_in int, y int, mut aa []u8, mut runs []i16) {
	b.record_min_y(y)
	b.check_for_y_gap(y)
	mut x := x_in
	mut i := 0
	for {
		count := int(runs[i])
		if count <= 0 {
			return
		}
		mut local_x := x
		mut local_count := count
		if x < b.left {
			gap := b.left - x
			local_x += gap
			local_count -= gap
		}
		right := x + count
		if right > b.right {
			local_count -= right - b.right
		}
		if local_count != 0 {
			b.builder.add_run(local_x, y, aa[i], local_count)
		}
		i += count
		x += count
	}
}

fn (mut b AAClipBuilderBlitter) blit_v(x int, y int, height int, alpha u8) {
	if height == 1 {
		mut aa := [alpha, 0]
		mut runs := [i16(1), 0]
		b.blit_anti_h(x, y, mut aa, mut runs)
	} else {
		b.record_min_y(y)
		b.builder.add_column(x, y, alpha, height)
		b.last_y = y + height - 1
	}
}

fn (mut b AAClipBuilderBlitter) blit_rect(x int, y int, width int, height int) {
	b.record_min_y(y)
	b.check_for_y_gap(y)
	b.builder.add_rect_run(x, y, width, height)
	b.last_y = y + height - 1
}

fn (mut b AAClipBuilderBlitter) blit_anti_rect(x int, y int, width int, height int, left_alpha u8, right_alpha u8) {
	b.record_min_y(y)
	b.check_for_y_gap(y)
	b.builder.add_anti_rect_run(x, y, width, height, left_alpha, right_alpha)
	b.last_y = y + height - 1
}

fn (mut b AAClipBuilderBlitter) blit_mask(mask &Mask, clip IRect) {
	panic('SkAAClip::Builder::Blitter does not take masks')
}

fn (mut b AAClipBuilderBlitter) blit_anti_h2(x int, y int, a0 u8, a1 u8) {
	default_blit_anti_h2(mut b, x, y, a0, a1)
}

fn (mut b AAClipBuilderBlitter) blit_anti_v2(x int, y int, a0 u8, a1 u8) {
	default_blit_anti_v2(mut b, x, y, a0, a1)
}

// SkAAClip::setPath() with doAA: the path's coverage within clip.
fn (mut c AAClip) set_path(path Path, clip IRect) bool {
	if clip.is_empty() {
		return c.set_empty()
	}
	mut ibounds := clip
	if !path.is_inverse_fill() {
		bounds := path.bounds() or { return c.set_empty() }
		rounded := round_out(bounds)
		if i64(rounded.right) - i64(rounded.left) <= 0 || i64(rounded.bottom) - i64(rounded.top) <= 0 {
			return c.set_empty()
		}
		ibounds = rounded.intersect(clip) or { return c.set_empty() }
	}
	mut builder := new_aaclip_builder(ibounds)
	mut blitter := AAClipBuilderBlitter{
		builder: &builder
		left:    ibounds.left
		right:   ibounds.right
	}
	// SkScan::AntiFillPath(raw, SkRegion(bounds), &blitter, true).
	anti_fill_region(path, path.convexity() != .concave, ibounds, mut blitter, true)
	if blitter.min_y < max_i32 {
		builder.min_y = blitter.min_y
	}
	return builder.finish(mut c)
}

// RowIter over one clip row.
struct AAClipRowIter {
	data         []u8
	has_row      bool
	bounds_right int
mut:
	index int
	left  int
	right int
	alpha u8
	done  bool
}

fn new_aaclip_row_iter(data []u8, has_row bool, bounds IRect) AAClipRowIter {
	if has_row {
		return AAClipRowIter{
			data:         data
			has_row:      true
			bounds_right: bounds.right
			left:         bounds.left
			right:        bounds.left + int(data[0])
			alpha:        data[1]
		}
	}
	return AAClipRowIter{
		bounds_right: bounds.right
		left:         bounds.left
		right:        max_i32
		done:         true
	}
}

fn (mut it AAClipRowIter) next() {
	if !it.done {
		it.left = it.right
		if it.right == it.bounds_right {
			it.done = true
			it.right = max_i32
			it.alpha = 0
		} else {
			it.index += 2
			it.right += int(it.data[it.index])
			it.alpha = it.data[it.index + 1]
		}
	}
}

// Iter over a clip's rows.
struct AAClipIter {
	clip &AAClip
mut:
	index  int
	top    int = max_i32
	bottom int = max_i32
	done   bool = true
}

fn new_aaclip_iter(clip &AAClip) AAClipIter {
	if clip.is_empty() {
		return AAClipIter{
			clip: unsafe { clip }
		}
	}
	return AAClipIter{
		clip:   unsafe { clip }
		top:    clip.bounds.top
		bottom: clip.bounds.top + clip.rows[0].y + 1
		done:   false
	}
}

fn (mut it AAClipIter) next() {
	if !it.done {
		it.top = it.bottom
		if it.index + 1 >= it.clip.rows.len {
			it.done = true
			it.bottom = max_i32
		} else {
			it.bottom += it.clip.rows[it.index + 1].y - it.clip.rows[it.index].y
			it.index++
		}
	}
}

// operateX() with the intersect proc.
fn (mut b AAClipBuilder) operate_x(last_y int, mut iter_a AAClipRowIter, mut iter_b AAClipRowIter) {
	mut left_a := iter_a.left
	mut rite_a := iter_a.right
	mut left_b := iter_b.left
	mut rite_b := iter_b.right
	mut prev_rite := b.bounds.left
	for {
		mut alpha_a := u8(0)
		mut alpha_b := u8(0)
		mut left := 0
		mut rite := 0
		if left_a < left_b {
			left = left_a
			alpha_a = iter_a.alpha
			if rite_a <= left_b {
				rite = rite_a
			} else {
				left_a = left_b
				rite = left_b
			}
		} else if left_b < left_a {
			left = left_b
			alpha_b = iter_b.alpha
			if rite_b <= left_a {
				rite = rite_b
			} else {
				left_b = left_a
				rite = left_a
			}
		} else {
			left = left_a
			m := if rite_b < rite_a { rite_b } else { rite_a }
			left_a = m
			left_b = m
			rite = m
			alpha_a = iter_a.alpha
			alpha_b = iter_b.alpha
		}
		if left >= b.bounds.right {
			break
		}
		if rite > b.bounds.right {
			rite = b.bounds.right
		}
		if left >= b.bounds.left {
			b.add_run(left, last_y, u8(mul_div255_round(alpha_a, alpha_b)), rite - left)
			prev_rite = rite
		}
		if rite == rite_a {
			iter_a.next()
			left_a = iter_a.left
			rite_a = iter_a.right
		}
		if rite == rite_b {
			iter_b.next()
			left_b = iter_b.left
			rite_b = iter_b.right
		}
		if iter_a.done && iter_b.done {
			break
		}
	}
	if prev_rite < b.bounds.right {
		b.add_run(prev_rite, last_y, 0, b.bounds.right - prev_rite)
	}
}

// operateY() for kIntersect.
fn (mut b AAClipBuilder) operate_y(a &AAClip, other &AAClip) {
	mut iter_a := new_aaclip_iter(a)
	mut iter_b := new_aaclip_iter(other)
	mut top_a := iter_a.top
	mut bot_a := iter_a.bottom
	mut top_b := iter_b.top
	mut bot_b := iter_b.bottom
	for {
		mut row_a := -1
		mut row_b := -1
		mut top := 0
		mut bot := 0
		if top_a < top_b {
			top = top_a
			row_a = if iter_a.done { -1 } else { iter_a.index }
			if bot_a <= top_b {
				bot = bot_a
			} else {
				top_a = top_b
				bot = top_b
			}
		} else if top_b < top_a {
			top = top_b
			row_b = if iter_b.done { -1 } else { iter_b.index }
			if bot_b <= top_a {
				bot = bot_b
			} else {
				top_b = top_a
				bot = top_a
			}
		} else {
			top = top_a
			m := if bot_b < bot_a { bot_b } else { bot_a }
			top_a = m
			top_b = m
			bot = m
			row_a = if iter_a.done { -1 } else { iter_a.index }
			row_b = if iter_b.done { -1 } else { iter_b.index }
		}
		if top >= b.bounds.bottom {
			break
		}
		if bot > b.bounds.bottom {
			bot = b.bounds.bottom
		}
		if row_a < 0 && row_b < 0 {
			b.add_run(b.bounds.left, bot - 1, 0, b.bounds.width())
		} else if top >= b.bounds.top {
			mut row_iter_a := if row_a >= 0 {
				new_aaclip_row_iter(a.rows[row_a].data, true, a.bounds)
			} else {
				new_aaclip_row_iter([]u8{}, false, b.bounds)
			}
			mut row_iter_b := if row_b >= 0 {
				new_aaclip_row_iter(other.rows[row_b].data, true, other.bounds)
			} else {
				new_aaclip_row_iter([]u8{}, false, b.bounds)
			}
			b.operate_x(bot - 1, mut row_iter_a, mut row_iter_b)
		}
		if bot == bot_a {
			iter_a.next()
			top_a = bot_a
			bot_a = iter_a.bottom
		}
		if bot == bot_b {
			iter_b.next()
			top_b = bot_b
			bot_b = iter_b.bottom
		}
		if iter_a.done && iter_b.done {
			break
		}
	}
}

// SkAAClip::op(other, kIntersect).
fn (mut c AAClip) op_clip(other &AAClip) bool {
	if c.is_empty() {
		return false
	}
	if other.is_empty() {
		return c.set_empty()
	}
	bounds := c.bounds.intersect(other.bounds) or { return c.set_empty() }
	mut builder := new_aaclip_builder(bounds)
	source := AAClip{
		bounds: c.bounds
		rows:   c.rows
	}
	builder.operate_y(&source, other)
	return builder.finish(mut c)
}

// SkAAClip::op(SkIRect, kIntersect).
fn (mut c AAClip) op_irect(rect IRect) bool {
	pixel_bounds := c.bounds.intersect(rect) or { return c.set_empty() }
	if pixel_bounds == c.bounds {
		return !c.is_empty()
	}
	if c.quick_contains(pixel_bounds.left, pixel_bounds.top, pixel_bounds.right, pixel_bounds.bottom) {
		return c.set_rect(pixel_bounds)
	}
	mut clip := AAClip{}
	clip.set_rect(rect)
	return c.op_clip(&clip)
}

// SkRect::contains(SkRect).
fn rect_contains_rect(a Rect, b Rect) bool {
	return !rect_is_empty(b) && !rect_is_empty(a) && a.left <= b.left && a.top <= b.top
		&& a.right >= b.right && a.bottom >= b.bottom
}

// SkPath::Rect(rect).
fn rect_path(r Rect) Path {
	mut b := PathBuilder{}
	b.add_rect_dir(r, true, 0)
	return b.detach()
}

// SkAAClip::op(SkRect, kIntersect, doAA).
fn (mut c AAClip) op_rect(rect Rect, do_aa bool) bool {
	if !do_aa {
		return c.op_irect(round_rect(rect))
	}
	pixel_bounds := c.bounds.intersect(round_out(rect)) or { return c.set_empty() }
	if rect_contains_rect(rect, Rect{f32(c.bounds.left), f32(c.bounds.top), f32(c.bounds.right), f32(c.bounds.bottom)}) {
		return !c.is_empty()
	}
	if c.quick_contains(pixel_bounds.left, pixel_bounds.top, pixel_bounds.right, pixel_bounds.bottom) {
		return c.set_path(rect_path(rect), pixel_bounds)
	}
	mut rect_clip := AAClip{}
	rect_clip.set_path(rect_path(rect), pixel_bounds)
	return c.op_clip(&rect_clip)
}

// SkRect::round(): sk_float_round2int() on each edge.
fn round_rect(r Rect) IRect {
	round := fn (v f32) int {
		rounded := f32(math.floor(f64(v) + 0.5))
		return int(saturate_to_i32(rounded))
	}
	return IRect{round(r.left), round(r.top), round(r.right), round(r.bottom)}
}

// SkAAClipBlitter.
struct AAClipBlitter {
	clip &AAClip
mut:
	inner Blitter
	runs  []i16
	aa    []u8
}

fn new_aaclip_blitter(inner Blitter, clip &AAClip) AAClipBlitter {
	count := clip.bounds.width() + 1
	return AAClipBlitter{
		clip:  unsafe { clip }
		inner: inner
		runs:  []i16{len: count}
		aa:    []u8{len: count}
	}
}

// expandToRuns().
fn (mut b AAClipBlitter) expand_to_runs(data []u8, start int, initial_count int, width_in int) {
	mut width := width_in
	mut n := initial_count
	mut i := start
	mut r := 0
	for {
		if n > width {
			n = width
		}
		b.runs[r] = i16(n)
		b.aa[r] = data[i + 1]
		r += n
		i += 2
		width -= n
		if width == 0 {
			break
		}
		n = int(data[i])
	}
	b.runs[r] = 0
}

fn (mut b AAClipBlitter) blit_h(x int, y int, width int) {
	row, _ := b.clip.find_row(y)
	data := b.clip.rows[row].data
	start, initial_count := b.clip.find_x(data, x)
	if initial_count >= width {
		alpha := data[start + 1]
		if alpha == 0 {
			return
		}
		if alpha == 0xff {
			b.inner.blit_h(x, y, width)
			return
		}
	}
	b.expand_to_runs(data, start, initial_count, width)
	b.inner.blit_anti_h(x, y, mut b.aa, mut b.runs)
}

// merge(): the source runs scaled by the clip row's coverage.
fn (mut b AAClipBlitter) merge(data []u8, start int, row_n_in int, src_aa []u8, src_runs []i16) {
	mut src_n := int(src_runs[0])
	if src_n == 0 {
		return
	}
	mut row_n := row_n_in
	mut i := start
	mut s := 0
	mut d := 0
	for {
		new_alpha := u8(mul_div255_round(src_aa[s], data[i + 1]))
		min_n := if row_n < src_n { row_n } else { src_n }
		b.runs[d] = i16(min_n)
		b.aa[d] = new_alpha
		d += min_n
		src_n -= min_n
		if src_n == 0 {
			src_n = int(src_runs[s])
			s += src_n
			src_n = int(src_runs[s])
			if src_n == 0 {
				break
			}
		}
		row_n -= min_n
		if row_n == 0 {
			i += 2
			row_n = int(data[i])
		}
	}
	b.runs[d] = 0
}

fn (mut b AAClipBlitter) blit_anti_h(x int, y int, mut aa []u8, mut runs []i16) {
	row, _ := b.clip.find_row(y)
	data := b.clip.rows[row].data
	start, initial_count := b.clip.find_x(data, x)
	b.merge(data, start, initial_count, aa, runs)
	b.inner.blit_anti_h(x, y, mut b.aa, mut b.runs)
}

fn (mut b AAClipBlitter) blit_v(x int, y_in int, height_in int, alpha u8) {
	if b.clip.quick_contains(x, y_in, x + 1, y_in + height_in) {
		b.inner.blit_v(x, y_in, height_in, alpha)
		return
	}
	mut y := y_in
	mut height := height_in
	for {
		row, last_y := b.clip.find_row(y)
		mut dy := last_y - y + 1
		if dy > height {
			dy = height
		}
		height -= dy
		data := b.clip.rows[row].data
		start, _ := b.clip.find_x(data, x)
		new_alpha := u8(mul_div255_round(alpha, data[start + 1]))
		if new_alpha != 0 {
			b.inner.blit_v(x, y, dy, new_alpha)
		}
		if height <= 0 {
			break
		}
		y = last_y + 1
	}
}

fn (mut b AAClipBlitter) blit_rect(x int, y_in int, width int, height_in int) {
	if b.clip.quick_contains(x, y_in, x + width, y_in + height_in) {
		b.inner.blit_rect(x, y_in, width, height_in)
		return
	}
	mut y := y_in
	mut height := height_in
	for {
		height--
		if height < 0 {
			break
		}
		b.blit_h(x, y, width)
		y++
	}
}

fn (mut b AAClipBlitter) blit_anti_rect(x int, y int, width int, height int, left_alpha u8, right_alpha u8) {
	default_blit_anti_rect(mut b, x, y, width, height, left_alpha, right_alpha)
}

// blitMask() for A8 masks: each row merged with the clip's coverage.
fn (mut b AAClipBlitter) blit_mask(mask &Mask, clip IRect) {
	if b.clip.quick_contains(clip.left, clip.top, clip.right, clip.bottom) {
		b.inner.blit_mask(mask, clip)
		return
	}
	width := clip.width()
	mut scratch := []u8{len: width}
	mut y := clip.top
	stop_y := clip.bottom
	for {
		row, last_y := b.clip.find_row(y)
		local_stop := if last_y + 1 < stop_y { last_y + 1 } else { stop_y }
		data := b.clip.rows[row].data
		start, initial_count := b.clip.find_x(data, clip.left)
		for {
			// mergeT<uint8_t>()
			src := mask.index(clip.left, y)
			mut src_n := width
			mut row_n := initial_count
			mut i := start
			mut o := 0
			for {
				n := if row_n < src_n { row_n } else { src_n }
				row_a := data[i + 1]
				for k in 0 .. n {
					scratch[o + k] = if row_a == 0xff {
						mask.image[src + o + k]
					} else if row_a == 0 {
						u8(0)
					} else {
						u8(mul_div255_round(mask.image[src + o + k], row_a))
					}
				}
				src_n -= n
				if src_n == 0 {
					break
				}
				o += n
				i += 2
				row_n = int(data[i])
			}
			row_mask := Mask{
				bounds:    IRect{clip.left, y, clip.right, y + 1}
				row_bytes: mask.row_bytes
				image:     scratch
			}
			b.inner.blit_mask(&row_mask, row_mask.bounds)
			y++
			if y >= local_stop {
				break
			}
		}
		if y >= stop_y {
			break
		}
	}
}

fn (mut b AAClipBlitter) blit_anti_h2(x int, y int, a0 u8, a1 u8) {
	default_blit_anti_h2(mut b, x, y, a0, a1)
}

fn (mut b AAClipBlitter) blit_anti_v2(x int, y int, a0 u8, a1 u8) {
	default_blit_anti_v2(mut b, x, y, a0, a1)
}

// SkRasterClip: a hard-edged rect (the BW region, always a rect here) or an
// SkAAClip.
pub struct RasterClip {
mut:
	is_bw    bool = true
	rect     IRect
	aa       AAClip
	is_empty bool
	is_rect  bool
}

fn new_raster_clip(bounds IRect) RasterClip {
	mut rc := RasterClip{}
	rc.set_bw_rect(bounds)
	return rc
}

// SkRegion::setRect().
fn (mut rc RasterClip) set_bw_rect(r IRect) {
	rc.rect = if r.is_empty() || r.right == max_i32 || r.bottom == max_i32 { IRect{} } else { r }
	rc.is_empty = rc.rect.is_empty()
	rc.is_rect = !rc.is_empty
}

fn (rc &RasterClip) bounds() IRect {
	return if rc.is_bw { rc.rect } else { rc.aa.bounds }
}

// updateCacheAndReturnNonEmpty().
fn (mut rc RasterClip) update_cache(detect_aa_rect bool) bool {
	rc.is_empty = if rc.is_bw { rc.rect.is_empty() } else { rc.aa.is_empty() }
	if detect_aa_rect && !rc.is_empty && !rc.is_bw && rc.aa.is_rect() {
		rc.rect = rc.aa.bounds
		rc.aa.set_empty()
		rc.is_bw = true
	}
	rc.is_rect = if rc.is_bw { !rc.rect.is_empty() } else { rc.aa.is_rect() }
	return !rc.is_empty
}

// convertToAA().
fn (mut rc RasterClip) convert_to_aa() {
	if rc.rect.is_empty() {
		rc.aa.set_empty()
	} else {
		rc.aa.set_rect(rc.rect)
	}
	rc.is_bw = false
	rc.update_cache(false)
}

// nearly_integral().
fn nearly_integral(x_in f32) bool {
	domain := f32(1) / f32(4)
	half_domain := domain / 2
	x := x_in + half_domain
	floored := floor_f32(x)
	return x - floored < domain
}

// SkRasterClip::op(rect, identity, kIntersect, doAA).
fn (mut rc RasterClip) op_rect(local Rect, do_aa bool) bool {
	// SkMatrix::mapRect() for the identity: translate by zero, then sort.
	return rc.op_device_rect(sort_as_rect(Rect{local.left + 0, local.top + 0, local.right + 0,
		local.bottom + 0}), do_aa)
}

// SkRasterClip::op(rect, matrix, kIntersect, doAA) for a scale-translate
// matrix once mapRect() has mapped the rect to dev.
fn (mut rc RasterClip) op_device_rect(dev Rect, do_aa_in bool) bool {
	mut do_aa := do_aa_in
	if rc.is_bw && do_aa {
		if nearly_integral(dev.left) && nearly_integral(dev.top) && nearly_integral(dev.right)
			&& nearly_integral(dev.bottom) {
			do_aa = false
		}
	}
	if rc.is_bw && !do_aa {
		// SkRegion::op(rect, kIntersect) on a rect region.
		if !rc.rect.is_empty() {
			rc.rect = rc.rect.intersect(round_rect(dev)) or { IRect{} }
		}
	} else {
		if rc.is_bw {
			rc.convert_to_aa()
		}
		rc.aa.op_rect(dev, do_aa)
	}
	return rc.update_cache(true)
}

// SkRasterClip::op(path, identity, kIntersect, doAA = true).
fn (mut rc RasterClip) op_path(path Path) bool {
	if rc.is_rect {
		if rc.is_bw {
			rc.convert_to_aa()
		}
		bounds := rc.bounds()
		rc.aa.set_path(path, bounds)
		return rc.update_cache(true)
	}
	// SkRasterClip(path, bounds, true), then op(clip): the other clip is AA.
	mut other := AAClip{}
	other.set_path(path, rc.bounds())
	if rc.is_bw {
		rc.convert_to_aa()
	}
	rc.aa.op_clip(&other)
	return rc.update_cache(true)
}

// canvas_raster_clip applies Canvas2D clip paths, captured in device space,
// to a width x height device as draw_canvas_command() does:
// SkCanvas::clipPath(path, kIntersect, true) before the matrix is set.
pub fn canvas_raster_clip(width int, height int, clips []Path) RasterClip {
	mut rc := new_raster_clip(IRect{0, 0, width, height})
	for clip in clips {
		if !clip.is_inverse_fill() {
			if r := clip.rect_contour() {
				rc.op_rect(r.rect, true)
				continue
			}
		}
		rc.op_path(clip)
	}
	return rc
}
