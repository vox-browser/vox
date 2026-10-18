module main

import layout

fn test_canvas_culling_preserves_complete_resource_and_effect_groups() {
	mut culling := PaintCanvasCulling{enabled: true}
	leaf := layout.PaintCommand{kind: 'fill_rect', x: 500, y: 500, width: 20, height: 20}
	assert culling.skip(leaf, 0, 0, 100, 100)
	for kind in ['begin_css_effect_layer', 'begin_background_text_clip', 'begin_svg_mask_layer'] {
		assert !culling.skip(layout.PaintCommand{kind: kind}, 0, 0, 100, 100)
		assert !culling.skip(leaf, 0, 0, 100, 100)
	}
	for kind in ['end_svg_mask_layer', 'end_background_text_clip', 'end_css_effect_layer'] {
		assert !culling.skip(leaf, 0, 0, 100, 100)
		assert !culling.skip(layout.PaintCommand{kind: kind}, 0, 0, 100, 100)
	}
	assert culling.skip(leaf, 0, 0, 100, 100)
	assert culling.depth == 0
}

fn test_canvas_culling_falls_through_when_disabled_or_unknown() {
	mut culling := PaintCanvasCulling{}
	leaf := layout.PaintCommand{kind: 'fill_rect', x: 500, y: 500, width: 20, height: 20}
	assert !culling.skip(leaf, 0, 0, 100, 100)
	culling.enabled = true
	assert !culling.skip(layout.PaintCommand{kind: 'future_paint_operation', x: 500, y: 500}, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'end_unknown_group'}, 0, 0, 100, 100)
	assert culling.depth == 0
	assert culling.skip(leaf, 0, 0, 100, 100)
}
