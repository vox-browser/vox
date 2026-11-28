module layout

import html

fn test_client_geometry_index_preserves_first_box_and_reads_live_context_values() {
	handle := unsafe { voidptr(u64(17)) }
	other := unsafe { voidptr(u64(18)) }
	mut result := DocumentLayoutResult{
		paint_tree: BlockBox{
			layout_handle: other
			accumulated_visual_context_index: 2
			children: [BlockBox{
				layout_handle: handle
				accumulated_visual_context_index: 3
			}, BlockBox{
				layout_handle: handle
				accumulated_visual_context_index: 8
			}]
		}
	}
	assert result.indexed_visual_context_for_layout_handle(handle)? == 3
	// Existing containing-block consumers still select the last transport box.
	assert result.retained_box_for_layout(handle)?.accumulated_visual_context_index == 8
	assert result.indexed_visual_context_for_layout_handle(other)? == 2
	assert result.indexed_visual_context_for_layout_handle(unsafe { voidptr(u64(19)) }) == none
	result.paint_tree.children[0].accumulated_visual_context_index = 11
	assert result.indexed_visual_context_for_layout_handle(handle)? == 11
	result.paint_tree = BlockBox{layout_handle: handle, accumulated_visual_context_index: 23}
	result.invalidate_boxes_by_layout_cache()
	assert voidptr(result.box_index) == unsafe { nil }
	assert result.indexed_visual_context_for_layout_handle(handle)? == 23
	assert result.indexed_visual_context_for_layout_handle(other) == none
}

fn verify_client_geometry_indices(mut result DocumentLayoutResult, node &Node) {
	handle := voidptr(node)
	assert result.indexed_visual_context_for_layout_handle(handle) ==
		visual_context_index_for_layout_handle(&result.paint_tree, handle)
	for child in node.children() { verify_client_geometry_indices(mut result, child) }
}

fn test_client_geometry_index_matches_recursive_lookup_after_animation_and_refresh() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}
		@keyframes slide{from{transform:translateX(0)}to{transform:translateX(100px)}}
		#target{width:30px;height:30px;animation:slide 1s linear forwards}
		#scroller{overflow:auto;height:80px}#tall{height:300px}</style>
		<div id="scroller"><div id="tall"><div id="target"><span>text</span></div></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut result := document_layout_result(document)?
	_ = document.record_display_list()?
	verify_client_geometry_indices(mut result, result.root)
	target := document.get_element_by_id('target')?
	assert target.get_bounding_client_rect().x == 0
	document.update_animations_and_send_events(500)
	document.update_layout(.html_event_loop_rendering_update)
	assert target.get_bounding_client_rect().x == 50
	verify_client_geometry_indices(mut result, result.root)
	handle := target.as_node().layout_node()?.real_layout_handle()
	previous_box := result.box_index.first[u64(handle)] or { panic('missing original box') }
	refresh_document_paint_tree(document, mut result, 320, 200)
	verify_client_geometry_indices(mut result, result.root)
	refreshed_box := result.box_index.first[u64(handle)] or { panic('missing refreshed box') }
	assert voidptr(previous_box) != voidptr(refreshed_box)
	assert target.get_bounding_client_rect().x == 50
}

fn test_client_geometry_index_reuses_its_arena_across_refresh_and_relayout() {
	mut document := html.parse_document('<!doctype html><div id="target">test</div>'
		+ '<div>another paint box</div>'.repeat(96))
	document.enable_native_storage()
	enable_native_paint_tree_storage(document)
	defer {
		retire_native_document_layout(document.layout_engine_handle())
		document.finalize()
		document.release_native_storage()
	}
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut result := document_layout_result(document)?
	target := document.get_element_by_id('target')?
	handle := target.as_node().layout_node()?.real_layout_handle()
	mut owner := document.enter_native_storage()
	defer { owner.finish() }
	storage := document.native_storage()
	before := if storage != unsafe { nil } { storage.arena.usage().used } else { i64(0) }
	arena := result.box_index_arena
	for _ in 0 .. 8 {
		result.invalidate_boxes_by_layout_cache()
		assert result.indexed_visual_context_for_layout_handle(handle) ==
			visual_context_index_for_layout_handle(&result.paint_tree, handle)
	}
	$if prealloc {
		assert voidptr(arena) != unsafe { nil }
		assert voidptr(result.box_index_arena) == voidptr(arena)
		assert storage.arena.usage().used == before
	}
	owner.finish()

	_ = layout_document_typed_in_viewport(document, 480, 240)
	mut resized := document_layout_result(document)?
	assert voidptr(resized) != voidptr(result)
	$if prealloc {
		assert voidptr(result.box_index_arena) == unsafe { nil }
		assert voidptr(resized.box_index_arena) == voidptr(arena)
	}
	verify_client_geometry_indices(mut resized, resized.root)
}
