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
