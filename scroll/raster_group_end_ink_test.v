module main

import layout

// A group end carries its group's extent, so a change to the end alone
// damages the pixels the group composites.
fn test_group_ends_carry_their_group_extent() {
	commands := [layout.PaintCommand{kind: 'begin_css_effect_layer'},
		layout.PaintCommand{kind: 'fill_rect', x: 60, y: 70, width: 40, height: 20, color: 'red'},
		layout.PaintCommand{kind: 'end_css_effect_layer'}]
	keys := scroll_raster_frame_keys(commands, 0, 1, 200, 200)
	assert keys[2].has_ink
	if retain_empty_group_end_ink {
		assert keys[2].ink == layout.LayoutRect{0, 0, 0, 0}
		return
	}
	assert keys[2].ink == keys[0].ink
	assert keys[2].ink.width > 0 && keys[2].ink.height > 0
	// The end changed alone: its group's pixels are damaged.
	mut changed := keys.clone()
	changed[2] = ScrollRasterCommandKey{...keys[2], hash: keys[2].hash + 1}
	previous := ScrollRasterKeyFrame{valid: true, document: 7, width: 200, height: 200, keys: keys}
	mut stats := ScrollRasterDiffStats{}
	rects := scroll_raster_content_damage(&previous, changed, 7, 0, 200, 200, mut stats) or {
		panic('changed group end must reconcile')
	}
	assert rects.any(it.x <= 60 && it.y <= 70 && it.x + it.width >= 100 && it.y + it.height >= 90)
}

// Removing one of several equal groups leaves the others' ends matched in
// order, so the frame reconciles by damaging the removed group.
fn test_removing_a_group_keeps_the_other_ends_in_order() {
	group := fn (x f64) []layout.PaintCommand {
		return [layout.PaintCommand{kind: 'begin_css_effect_layer', x: x},
			layout.PaintCommand{kind: 'fill_rect', x: x, y: 70, width: 20, height: 20, color: 'red'},
			layout.PaintCommand{kind: 'end_css_effect_layer'}]
	}
	mut before := group(20)
	before << group(80)
	before << group(140)
	mut after := [layout.PaintCommand{kind: 'fill_rect', x: 20, y: 70, width: 20, height: 20, color: 'red'}]
	after << group(80)
	after << group(140)
	previous := ScrollRasterKeyFrame{valid: true, document: 7, width: 200, height: 200,
		keys: scroll_raster_frame_keys(before, 0, 1, 200, 200)}
	mut stats := ScrollRasterDiffStats{}
	result := scroll_raster_content_damage(&previous, scroll_raster_frame_keys(after, 0, 1, 200, 200),
		7, 0, 200, 200, mut stats)
	if retain_shared_group_end_keys {
		// Equal ends match the removed one out of order.
		if !paint_order_damage_enabled {
			assert result == none && stats.fallback == 'paint-order-changed'
		}
		return
	}
	if retain_empty_group_end_ink { return }
	rects := result or { panic('removing a group must reconcile: ${stats.fallback}') }
	assert rects.len > 0
	assert !rects.any(scroll_raster_rects_overlap(it, layout.LayoutRect{145, 75, 10, 10}))
}
