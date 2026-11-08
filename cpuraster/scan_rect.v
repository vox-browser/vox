module cpuraster

// SkScan::AntiFillRect: clip before converting to 16.16, then round to
// 24.8. Rectangles use this coverage calculation rather than the path walker.
fn anti_fill_rect(rect Rect, rc &RasterClip, mut blitter Blitter) {
	if rc.is_empty { return }
	b := rc.bounds()
	r := rect_intersect(rect, Rect{f32(b.left), f32(b.top), f32(b.right), f32(b.bottom)}) or { return }
	if rc.is_bw { anti_fill_rect_unclipped(r, mut blitter) }
	else {
		mut wrapper := new_aaclip_blitter(blitter, &rc.aa)
		anti_fill_rect_unclipped(r, mut wrapper)
	}
}

fn rect_dot8(x f32) int {
	return (int(float_saturate2int(x * f32(65536))) + 128) >> 8
}

fn rect_scanline(l int, y int, r int, alpha int, mut blitter Blitter, mut scratch HairScratch) {
	if l >> 8 == (r - 1) >> 8 {
		blitter.blit_v(l >> 8, y, 1, u8((alpha * (r - l)) >> 8))
		return
	}
	mut left := l >> 8
	if l & 255 != 0 {
		blitter.blit_v(left, y, 1, u8((alpha * (256 - (l & 255))) >> 8))
		left++
	}
	right := r >> 8
	if right > left { call_hline_blitter(mut blitter, left, y, right - left, u8(alpha), mut scratch) }
	if r & 255 != 0 { blitter.blit_v(right, y, 1, u8((alpha * (r & 255)) >> 8)) }
}

fn anti_fill_rect_unclipped(r Rect, mut blitter Blitter) {
	l, t, right, bottom := rect_dot8(r.left), rect_dot8(r.top), rect_dot8(r.right), rect_dot8(r.bottom)
	if l >= right || t >= bottom { return }
	mut scratch := HairScratch{
		aa: []u8{len: hline_stack_buffer}
		runs: []i16{len: hline_stack_buffer + 1}
	}
	mut top := t >> 8
	if top == (bottom - 1) >> 8 {
		rect_scanline(l, top, right, bottom - t - 1, mut blitter, mut scratch)
		return
	}
	if t & 255 != 0 {
		rect_scanline(l, top, right, 256 - (t & 255), mut blitter, mut scratch)
		top++
	}
	bot := bottom >> 8
	if bot > top {
		mut left := l >> 8
		if left == (right - 1) >> 8 { blitter.blit_v(left, top, bot - top, u8(right - l - 1)) }
		else {
			if l & 255 != 0 { blitter.blit_v(left, top, bot - top, u8(256 - (l & 255))); left++ }
			rite := right >> 8
			if rite > left { blitter.blit_rect(left, top, rite - left, bot - top) }
			if right & 255 != 0 { blitter.blit_v(rite, top, bot - top, u8(right & 255)) }
		}
	}
	if bottom & 255 != 0 { rect_scanline(l, bot, right, bottom & 255, mut blitter, mut scratch) }
}
