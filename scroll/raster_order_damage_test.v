module main

import layout

fn order_damage_key(hash u64, x f64, y f64) ScrollRasterCommandKey {
	return ScrollRasterCommandKey{hash: hash, kind: 'fill_rect', has_ink: true,
		ink: layout.LayoutRect{x, y, 20, 20}}
}

fn order_damage_covers(rects []layout.LayoutRect, target layout.LayoutRect) bool {
	return rects.any(it.x <= target.x && it.y <= target.y && it.x + it.width >= target.x + target.width
		&& it.y + it.height >= target.y + target.height)
}

// Two overlapping commands that swap paint order damage their overlap; an
// unrelated command elsewhere stays undamaged.
fn test_reordered_commands_damage_their_overlap() {
	if !paint_order_damage_enabled { return }
	far := order_damage_key(9, 160, 160)
	below := order_damage_key(1, 20, 20)
	above := order_damage_key(2, 30, 30)
	previous := ScrollRasterKeyFrame{valid: true, document: 7, width: 200, height: 200,
		keys: [far, below, above]}
	mut stats := ScrollRasterDiffStats{}
	rects := scroll_raster_content_damage(&previous, [far, above, below], 7, 0, 200, 200, mut stats) or {
		panic('swapped commands must reconcile')
	}
	assert stats.reordered == 1
	assert order_damage_covers(rects, layout.LayoutRect{30, 30, 10, 10})
	assert !rects.any(scroll_raster_rects_overlap(it, layout.LayoutRect{165, 165, 10, 10}))
}
