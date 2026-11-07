module layout

import html

fn raster_plan_signature(plan ChromiumRasterLayerPlan) string {
	mut parts := []string{}
	parts << plan.command_layers.map(it.str()).join(',')
	for layer in plan.layers {
		parts << '${layer.bounds}|${layer.legacy_raster}|${layer.composited_contents}|${layer.command_indices}'
	}
	return parts.join(';')
}

// The cached candidates must be a superset of every entry the per-frame passes
// act on, so the raster plan and fixed-background invalidation are unchanged.
fn test_entry_candidates_keep_the_raster_plan_and_fixed_background_invalidation() {
	mut rows := ''
	for index in 0 .. 40 {
		rows += '<p>row ${index} with text</p>'
	}
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#fixed{position:fixed;top:4px;left:300px;width:60px;height:30px;background:blue}#sticky{position:sticky;top:0;height:20px;background:yellow}#scroller{height:60px;overflow:auto}#scroller p{margin:0;height:30px}#effect{will-change:transform;opacity:.5;width:50px;height:50px;background:red}#bg{height:80px;background:url(data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7) fixed}</style><div id="sticky">sticky</div><div id="fixed"></div><div id="scroller">' + '<p>inner</p>'.repeat(6) + '</div><div id="effect"></div><div id="bg"></div>' + rows)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 400, 200)
	commands := display_list_commands(document.record_viewport_display_list() or { panic('missing list') })
	mut result := document_layout_result(document) or { panic('missing result') }
	candidates := viewport_entry_candidates(mut result)
	assert candidates.valid
	assert candidates.raster_layers.len > 0 && candidates.raster_layers.len < result.paint_order.len
	assert candidates.fixed_backgrounds.len == 1
	for index, entry in result.paint_order {
		box := entry.box
		if chromium_user_scrollable_box(box) || box.sticky_scroll_frame_index > 0
			|| (box.chromium_compositor_surface && box.own_effects_visual_context_idx > 0)
			|| box.fixed_to_viewport {
			assert index in candidates.raster_layers, 'entry ${index}'
		}
	}
	mut plan := ChromiumRasterLayerPlan{}
	update_chromium_raster_layer_plan_with_cull(document, commands, 2, LayoutRect{0, 0, 400, 200}, mut plan)
	cached := raster_plan_signature(plan)
	// Every entry as a candidate reproduces the complete per-frame scan.
	result.entry_candidates.raster_layers = []int{len: result.paint_order.len, init: index}
	mut full := ChromiumRasterLayerPlan{}
	update_chromium_raster_layer_plan_with_cull(document, commands, 2, LayoutRect{0, 0, 400, 200}, mut full)
	assert raster_plan_signature(full) == cached
	// The fixed background entry is still invalidated on every recording.
	fixed := candidates.fixed_backgrounds[0]
	result.paint_phase_entry_valid[fixed] = true
	viewport_invalidate_fixed_background_paint_caches(mut result)
	assert !result.paint_phase_entry_valid[fixed]
	// A paint revision change rebuilds the candidates.
	revision := result.entry_candidates.revision
	document.set_needs_repaint()
	_ = viewport_entry_candidates(mut result)
	assert result.entry_candidates.revision != revision
}
