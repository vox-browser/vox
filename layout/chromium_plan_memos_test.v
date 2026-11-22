module layout

import html

fn plan_memo_effect_scope_walk(result &DocumentLayoutResult, context int, bounds map[u64]LayoutRect) u64 {
	mut ancestor := context
	for ancestor > 0 && ancestor < result.visual_context_tree.nodes.len {
		if u64(ancestor) in bounds { return u64(ancestor) }
		ancestor = result.visual_context_tree.nodes[ancestor].parent_index
	}
	return 0
}

fn test_layerization_memos_match_the_direct_ancestor_walks() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#clip{overflow:hidden;width:80px;height:40px;transform:translateX(3px)}#pos{position:relative;left:2px}</style><div id="clip"><div id="pos"><span>text</span><svg width="10" height="10"><rect width="5" height="5"/></svg></div><p>more</p></div><div>outside</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	_ = record_retained_display_list(mut document) or { panic('missing paint') }
	result := document_layout_result(document) or { panic('missing layout') }
	assert result.paint_order.len > 4
	mut bounds := map[u64]LayoutRect{}
	for entry in result.paint_order {
		if entry.box.own_effects_visual_context_idx > 0 {
			bounds[u64(entry.box.own_effects_visual_context_idx)] = entry.box.border_box()
		}
	}
	mut memos := ChromiumRasterPlanMemos{}
	memos.begin(result.visual_context_tree.nodes.len)
	for _ in 0 .. 2 {
		for entry in result.paint_order {
			box := entry.box
			context := box.accumulated_visual_context_index
			if !disable_raster_plan_memos { assert memos.active }
			assert memos.paint_client(box) == chromium_paint_client(box)
			assert memos.context_clip(result, context) == compatibility_visual_context_clip(&result.visual_context_tree,
				context, result.scroll_state_snapshot)
			assert memos.effect_scope(result, context, bounds) == plan_memo_effect_scope_walk(result,
				context, bounds)
		}
	}
	memos.end()
	assert !memos.active
	// After the layerization, lookups compute afresh instead of reading memos.
	first := result.paint_order[0].box
	assert memos.paint_client(first) == chromium_paint_client(first)
	// A later layerization starts from new stamps.
	generation := memos.generation
	memos.begin(result.visual_context_tree.nodes.len)
	assert memos.generation == generation + 1 && memos.clients.len == 0
}
