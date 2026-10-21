module main

import layout

fn test_canvas_culling_preserves_complete_resource_and_effect_groups() {
	mut culling := PaintCanvasCulling{enabled: true}
	leaf := layout.PaintCommand{kind: 'fill_rect', x: 500, y: 500, width: 20, height: 20}
	assert culling.skip(leaf, 0, 0, 100, 100)
	for kind in ['begin_css_filter_layer', 'begin_background_text_clip', 'begin_svg_mask_layer'] {
		assert !culling.skip(layout.PaintCommand{kind: kind}, 0, 0, 100, 100)
		assert !culling.skip(leaf, 0, 0, 100, 100)
	}
	for kind in ['end_svg_mask_layer', 'end_background_text_clip', 'end_css_filter_layer'] {
		assert !culling.skip(leaf, 0, 0, 100, 100)
		assert !culling.skip(layout.PaintCommand{kind: kind}, 0, 0, 100, 100)
	}
	assert culling.skip(leaf, 0, 0, 100, 100)
	assert culling.depth == 0
}

fn test_canvas_culling_keeps_visible_opacity_scopes_but_discards_their_offscreen_leaves() {
	mut culling := PaintCanvasCulling{enabled: true}
	assert !culling.skip(layout.PaintCommand{kind: 'begin_css_effect_layer'}, 0, 0, 100, 100)
	assert culling.skip(layout.PaintCommand{kind: 'fill_rect', x: 500, y: 500, width: 20, height: 20}, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'fill_rect', x: 10, y: 10, width: 20, height: 20}, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'begin_css_filter_layer'}, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'fill_rect', x: 500, y: 500, width: 20, height: 20}, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'end_css_filter_layer'}, 0, 0, 100, 100)
	assert culling.resource_depth == 0 && culling.depth == 1
	assert !culling.skip(layout.PaintCommand{kind: 'end_css_effect_layer'}, 0, 0, 100, 100)
	assert culling.depth == 0
}

fn test_canvas_culling_discards_a_complete_offscreen_opacity_scope_with_balanced_nested_groups() {
	mut culling := PaintCanvasCulling{enabled: true}
	outside := layout.PaintCommand{kind: 'begin_css_effect_layer', has_clip: true,
		clip_x: 0, clip_y: 104, clip_width: 100, clip_height: 30}
	assert culling.skip(outside, 0, 0, 100, 100)
	for kind in ['begin_svg_mask_layer', 'begin_css_effect_layer', 'fill_rect',
		'end_css_effect_layer', 'end_svg_mask_layer', 'end_css_effect_layer'] {
		assert culling.skip(layout.PaintCommand{kind: kind}, 0, 0, 100, 100)
	}
	assert culling.skipped_depth == 0 && culling.depth == 0 && culling.resource_depth == 0
	assert !culling.skip(layout.PaintCommand{kind: 'fill_rect', x: 10, y: 10, width: 10, height: 10}, 0, 0, 100, 100)
	// Preserve the native clip's fringe and translated clips which reach ink.
	assert !culling.skip(outside, 0, -2, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'end_css_effect_layer'}, 0, 0, 100, 100)
	// A resource's source-space opacity scope may be consumed onscreen later.
	assert !culling.skip(layout.PaintCommand{kind: 'begin_background_text_clip'}, 0, 0, 100, 100)
	assert !culling.skip(outside, 0, 0, 100, 100)
}

fn test_canvas_culling_skips_the_complete_output_of_an_offscreen_text_mask() {
	mut culling := PaintCanvasCulling{enabled: true}
	outside := layout.PaintCommand{kind: 'begin_background_text_clip', x: 500, y: 500,
		width: 40, height: 20}
	assert culling.skip(outside, 0, 0, 100, 100)
	assert culling.skip(layout.PaintCommand{kind: 'fill_gradient'}, 0, 0, 100, 100)
	assert culling.skip(layout.PaintCommand{kind: 'end_background_text_clip'}, 0, 0, 100, 100)
	assert culling.depth == 0 && culling.skipped_depth == 0
	// Map the final output rectangle before deciding whether its inputs matter.
	translated := layout.PaintCommand{...outside, transform: [1.0, 0, 0, 1, -500, -500]!}
	assert !culling.skip(translated, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'fill_gradient'}, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'end_background_text_clip'}, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'begin_svg_mask_layer'}, 0, 0, 100, 100)
	assert !culling.skip(outside, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'end_background_text_clip'}, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'end_svg_mask_layer'}, 0, 0, 100, 100)
	assert culling.depth == 0 && culling.resource_depth == 0
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
