module layout

import dom
import html
import painting

fn frame_cost_paint_box_for_handle(box &BlockBox, handle voidptr) ?&BlockBox {
	if box.layout_handle == handle { return unsafe { box } }
	for index in 0 .. box.children.len {
		if found := frame_cost_paint_box_for_handle(unsafe { &box.children[index] }, handle) {
			return found
		}
	}
	return none
}

fn test_transform_samples_keep_paint_and_hit_test_plans() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes slide{from{transform:translateX(0)}to{transform:translateX(100px)}}#target{width:30px;height:30px;background:rgb(71 72 73);animation:slide 1s linear forwards}</style><div id="target"></div><div id="other">other</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut result := document_layout_result(document) or { panic('missing layout') }
	target := document.get_element_by_id('target') or { panic('missing target') }
	initial := document.record_display_list() or { panic('missing paint') }
	initial_dump := initial.dump()
	_ = document.element_from_point(10, 10) or { panic('missing initial hit') }
	paint_steps := result.paint_steps.data
	hit_test_steps := result.hit_test_steps.data
	assert result.hit_test_display_list_is_valid
	document.update_animations_and_send_events(500)
	document.update_layout(.html_event_loop_rendering_update)
	sampled := document.record_display_list() or { panic('missing sampled paint') }
	assert result.paint_steps.data == paint_steps
	assert result.hit_test_display_list_is_valid
	assert result.hit_test_steps.data == hit_test_steps
	assert sampled.dump() == initial_dump
	moved := display_list_commands(sampled).filter(it.color == 'rgb(71 72 73)')
	assert moved.len == 1
	// Compositor samples update the retained visual context; cached commands
	// keep their original local transform while paint and hit-test plans survive.
	layout_node := target.as_node().layout_node() or { panic('missing target layout') }
	box := result.retained_box_for_layout(layout_node.layout_handle) or { panic('missing target box') }
	assert box.own_transform_visual_context_idx > 0
	transform := result.visual_context_tree.node_at(box.own_transform_visual_context_idx).data as painting.TransformVisualData
	assert transform.uses_matrix_4x4
	assert transform.matrix_4x4.m14 == 50
	assert (document.element_from_point(60, 10) or { panic('missing moved hit') }) == target
	assert (document.element_from_point(10, 10) or { panic('missing vacated hit') }) != target
	sampled_dump := sampled.dump()
	refresh_document_paint_tree(document, mut result, 320, 200)
	assert (document.record_display_list() or { panic('missing full paint') }).dump() == sampled_dump
}

fn test_singular_transform_samples_still_rebuild_the_paint_plan() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes collapse{from{transform:scale(1)}to{transform:scale(0)}}#target{width:30px;height:30px;background:rgb(71 72 73);animation:collapse 1s linear forwards}</style><div id="target"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut result := document_layout_result(document) or { panic('missing layout') }
	initial := document.record_display_list() or { panic('missing paint') }
	assert display_list_commands(initial).any(it.color == 'rgb(71 72 73)')
	document.update_animations_and_send_events(1000)
	document.update_layout(.html_event_loop_rendering_update)
	collapsed := document.record_display_list() or { panic('missing collapsed paint') }
	assert !display_list_commands(collapsed).any(it.color == 'rgb(71 72 73)')
	collapsed_dump := collapsed.dump()
	refresh_document_paint_tree(document, mut result, 320, 200)
	assert (document.record_display_list() or { panic('missing full paint') }).dump() == collapsed_dump
}

fn test_viewport_scroll_rerecords_commands_but_keeps_the_hit_test_plan() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}div{height:150px;background:rgb(71 72 73)}</style><div id="first"></div><div id="second"></div><div id="third"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	result := document_layout_result(document) or { panic('missing layout') }
	initial := document.record_display_list() or { panic('missing paint') }
	initial_dump := initial.dump()
	_ = document.element_from_point(10, 10) or { panic('missing hit') }
	hit_test_steps := result.hit_test_steps.data
	viewport := document.viewport_rect()
	document.set_viewport_rect(dom.Rect{viewport.x, 160, viewport.width, viewport.height})
	assert result.hit_test_display_list_is_valid
	scrolled := document.record_display_list() or { panic('missing scrolled paint') }
	assert scrolled.dump() != initial_dump
	assert result.hit_test_steps.data == hit_test_steps
	second := document.get_element_by_id('second') or { panic('missing second') }
	assert (document.element_from_point(10, 10) or { panic('missing scrolled hit') }) == second
}

fn test_retained_box_index_follows_paint_tree_refresh_and_excludes_the_viewport() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{margin-left:12px;width:30px;height:30px}</style><div id="target"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut result := document_layout_result(document) or { panic('missing layout') }
	target := document.get_element_by_id('target') or { panic('missing target') }
	placeholder := target.as_node().layout_node() or { panic('missing target layout') }
	handle := placeholder.layout_handle
	first := result.retained_box_for_layout(handle) or { panic('missing indexed box') }
	assert voidptr(first) == voidptr(frame_cost_paint_box_for_handle(&result.paint_tree, handle) or {
		panic('missing tree box')
	})
	assert result.retained_box_for_layout(voidptr(result.root)) == none
	position := layout_paintable_box_type_agnostic_position(voidptr(result), handle)
	assert position.x() == 12
	refresh_document_paint_tree(document, mut result, 320, 200)
	refreshed := result.retained_box_for_layout(handle) or { panic('missing refreshed box') }
	assert voidptr(refreshed) == voidptr(frame_cost_paint_box_for_handle(&result.paint_tree,
		handle) or { panic('missing refreshed tree box') })
	assert voidptr(refreshed) != voidptr(first)
}
