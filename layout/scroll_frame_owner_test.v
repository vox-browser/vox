module layout

import dom
import html

fn scroll_owner_test_box(document &dom.Document, mut result DocumentLayoutResult, id string) &BlockBox {
	element := document.get_element_by_id(id) or { panic('missing ${id}') }
	layout_node := element.as_node().layout_node() or { panic('missing ${id} layout') }
	return result.retained_box_for_layout(layout_node.layout_handle) or { panic('missing ${id} box') }
}

fn test_scroll_frame_assignment_crosses_ordinary_boxes_and_resets_old_indices() {
	mut document := html.parse_document('<!doctype html><style>
		html,body{margin:0}
		#outer{width:100px;height:60px;overflow:auto}
		#inner{height:100px;overflow:hidden}
		#sticky{position:sticky;top:0;height:10px}
		#spacer{height:200px}
	</style><div id="outer"><div id="plain"><div id="inner"><div id="bridge"><div id="sticky"></div><div id="spacer"></div></div></div></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 240)
	mut result := document_layout_result(document) or { panic('missing layout') }
	outer_box := scroll_owner_test_box(document, mut result, 'outer')
	inner_box := scroll_owner_test_box(document, mut result, 'inner')
	sticky_box := scroll_owner_test_box(document, mut result, 'sticky')
	mut plain_box := scroll_owner_test_box(document, mut result, 'plain')
	mut bridge_box := scroll_owner_test_box(document, mut result, 'bridge')
	frame_count := result.scroll_state.frames.len
	assert frame_count == 5
	// Reassignment must clear stale frame ownership without pruning descendants.
	plain_box.own_scroll_frame_index = 97
	plain_box.sticky_scroll_frame_index = 98
	bridge_box.own_scroll_frame_index = 99
	rebuild_compatibility_visual_contexts(mut result)
	assert result.scroll_state.frames.len == frame_count
	assert plain_box.own_scroll_frame_index == 0
	assert plain_box.sticky_scroll_frame_index == 0
	assert bridge_box.own_scroll_frame_index == 0
	assert outer_box.own_scroll_frame_index > 0
	assert inner_box.own_scroll_frame_index > 0
	assert sticky_box.sticky_scroll_frame_index > 0
	assert result.scroll_state.frame_at(inner_box.own_scroll_frame_index).parent_index() == outer_box.own_scroll_frame_index
	assert result.scroll_state.frame_at(sticky_box.sticky_scroll_frame_index).parent_index() == inner_box.own_scroll_frame_index
}

fn test_sticky_scroll_owner_keeps_both_frames_and_descendant_parentage() {
	mut document := html.parse_document('<!doctype html><style>
		html,body{margin:0}
		#sticky{position:sticky;top:0;width:100px;height:50px;overflow:auto}
		#child{height:100px;overflow:hidden}
		#spacer{height:200px}
	</style><div id="sticky"><div><div id="child"><div id="spacer"></div></div></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 240)
	mut result := document_layout_result(document) or { panic('missing layout') }
	sticky_box := scroll_owner_test_box(document, mut result, 'sticky')
	child_box := scroll_owner_test_box(document, mut result, 'child')
	assert sticky_box.sticky_scroll_frame_index > 0
	assert sticky_box.own_scroll_frame_index > sticky_box.sticky_scroll_frame_index
	assert result.scroll_state.frame_at(sticky_box.own_scroll_frame_index).parent_index() == sticky_box.sticky_scroll_frame_index
	assert result.scroll_state.frame_at(child_box.own_scroll_frame_index).parent_index() == sticky_box.own_scroll_frame_index
}
