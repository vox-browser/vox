module main

import layout
import painting

fn backdrop_button(x f64, y f64) layout.PaintCommand {
	return layout.PaintCommand{
		kind:                 'apply_backdrop_filter'
		x:                    x
		y:                    y
		width:                40
		height:               20
		backdrop_filter_data: &painting.GfxFilter{operations: [painting.GfxFilterOperation{kind: 'blur', first: 4}]}
	}
}

fn backdrop_leaf(x f64, y f64, color string) layout.PaintCommand {
	return layout.PaintCommand{kind: 'fill_rect', x: x, y: y, width: 10, height: 10, color: color}
}

fn backdrop_damage(before []layout.PaintCommand, after []layout.PaintCommand, scroll f64) ?[]layout.LayoutRect {
	old := scroll_raster_frame_keys(before, 0, 1, 400, 400)
	keys := scroll_raster_frame_keys(after, scroll, 1, 400, 400)
	previous := ScrollRasterKeyFrame{valid: true, document: 7, width: 400, height: 400, keys: old}
	mut stats := ScrollRasterDiffStats{}
	return scroll_raster_content_damage(&previous, keys, 7, scroll, 400, 400, mut stats)
}

fn rects_cover(rects []layout.LayoutRect, target layout.LayoutRect) bool {
	return rects.any(it.x <= target.x && it.y <= target.y && it.x + it.width >= target.x + target.width
		&& it.y + it.height >= target.y + target.height)
}

// Lists with a bounded backdrop filter keep the retained raster. A change far
// from the backdrop damages only itself; one inside the region the filter
// samples repaints that whole region; an unchanged backdrop recorded again
// is not damaged.
fn test_backdrop_filters_repaint_their_read_region_with_nearby_damage() {
	far := backdrop_leaf(300, 300, 'red')
	near := backdrop_leaf(30, 30, 'red')
	before := [far, near, backdrop_button(50, 40)]
	if layout.retain_backdrop_raster_rejection {
		assert !layout.scroll_raster_commands_reusable(before, 400, 400)
		return
	}
	assert layout.scroll_raster_commands_reusable(before, 400, 400)
	read := layout.scroll_raster_leaf_ink_bounds(&before[2]) or { panic('backdrop ink') }
	// An identical list (the filter recorded again) has no damage.
	assert (backdrop_damage(before, [far, near, backdrop_button(50, 40)], 0) or { panic('same') }).len == 0
	// Far change: only its own ink.
	far_change := backdrop_damage(before, [backdrop_leaf(300, 300, 'blue'), near, backdrop_button(50, 40)],
		0) or { panic('far') }
	assert !rects_cover(far_change, read)
	// Change inside the sampled region: the whole region repaints.
	near_change := backdrop_damage(before, [far, backdrop_leaf(30, 30, 'blue'), backdrop_button(50, 40)],
		0) or { panic('near') }
	assert rects_cover(near_change, layout.scroll_raster_rect_intersect(read,
		layout.LayoutRect{0, 0, 400, 400}))
	// The skip plan replays the backdrop with that damage.
	keys := scroll_raster_frame_keys([far, backdrop_leaf(30, 30, 'blue'), backdrop_button(50, 40)], 0,
		1, 400, 400)
	plan := plan_scroll_raster_skips([far, backdrop_leaf(30, 30, 'blue'), backdrop_button(50, 40)],
		keys, near_change, false)
	assert !plan[1] && !plan[2]
}

// A backdrop inside an opacity layer keeps the retained raster; inside a
// spatial filter layer it does not.
fn test_backdrops_inside_effect_layers_keep_the_retained_raster() {
	if layout.retain_backdrop_raster_rejection { return }
	effect := [layout.PaintCommand{kind: 'begin_css_effect_layer'}, backdrop_button(50, 40),
		layout.PaintCommand{kind: 'end_css_effect_layer'}]
	assert layout.scroll_raster_commands_reusable(effect, 400, 400)
	filtered := [layout.PaintCommand{kind: 'begin_css_filter_layer', visual_layer_data: &layout.PaintVisualLayer{
		kind: .css_filter
		filter: painting.GfxFilter{operations: [painting.GfxFilterOperation{kind: 'blur', first: 4}]}
	}}, backdrop_button(50, 40), layout.PaintCommand{kind: 'end_css_filter_layer'}]
	assert !layout.scroll_raster_commands_reusable(filtered, 400, 400)
}
