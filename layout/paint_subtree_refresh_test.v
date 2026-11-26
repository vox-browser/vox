module layout

import dom
import html

fn subtree_refresh_box_for_handle(box &BlockBox, handle voidptr) ?&BlockBox {
	if box.layout_handle == handle { return unsafe { box } }
	for index in 0 .. box.children.len {
		if found := subtree_refresh_box_for_handle(unsafe { &box.children[index] }, handle) {
			return found
		}
	}
	return none
}

fn subtree_refresh_box_for_id(document &dom.Document, result &DocumentLayoutResult, id string) &BlockBox {
	element := document.get_element_by_id(id) or { panic('missing ${id}') }
	layout_node := element.as_node().layout_node() or { panic('missing ${id} layout') }
	return subtree_refresh_box_for_handle(&result.paint_tree, layout_node.layout_handle) or {
		panic('missing ${id} transport')
	}
}

fn test_category_change_projects_only_the_changed_subtree_like_a_full_refresh() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#outer{padding:4px}#a{width:40px;height:20px;background:rgb(10 20 30)}#a.faded{opacity:0.5;transform:translateX(5px)}#b{width:30px;height:10px;background:green}</style><div id="outer"><div id="wrap"><div id="a"><span>text</span></div></div><div id="b">other</div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut result := document_layout_result(document) or { panic('missing layout') }
	_ = record_retained_display_list(mut document) or { panic('missing paint') }
	sibling := subtree_refresh_box_for_id(document, result, 'b')
	sibling_lines := sibling.lines.data
	mut target := document.get_element_by_id('a') or { panic('missing target') }
	target.set_attribute_value('class', 'faded')
	document.update_layout(.html_event_loop_rendering_update)
	refreshed := record_retained_display_list(mut document) or { panic('missing refreshed paint') }
	refreshed_dump := refreshed.dump()
	// The sibling outside the changed subtree keeps its retained box.
	retained_sibling := subtree_refresh_box_for_id(document, result, 'b')
	assert voidptr(retained_sibling) == voidptr(sibling)
	assert retained_sibling.lines.data == sibling_lines
	changed := subtree_refresh_box_for_id(document, result, 'a')
	assert changed.opacity == 0.5
	assert !changed.uses_own_paint_transform_4x4 || changed.paint_transform[4] != 0
	refresh_document_paint_tree(document, mut result, 320, 200)
	assert (record_retained_display_list(mut document) or { panic('missing full paint') }).dump() == refreshed_dump
}

fn test_root_children_and_inline_updates_keep_the_complete_refresh() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#top{width:40px;height:20px}#top.faded{opacity:0.5}</style><div id="top">text</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut result := document_layout_result(document) or { panic('missing layout') }
	_ = record_retained_display_list(mut document) or { panic('missing paint') }
	top := document.get_element_by_id('top') or { panic('missing top') }
	layout_node := top.as_node().layout_node() or { panic('missing top layout') }
	result.paint_style_update_handles.add(u64(layout_node.layout_handle))
	// The box's retained parent is body, which paints into the canvas.
	assert plan_paint_subtree_refresh(mut result) == none
	result.paint_style_update_handles.clear()
	assert plan_paint_subtree_refresh(mut result) == none
}

fn test_transition_sample_projects_the_changed_subtree_like_a_full_refresh() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#outer{padding:2px}#a{width:40px;height:20px;background-color:rgb(0 0 0);transition:background-color 1s linear}#a.lit{background-color:rgb(200 100 0)}#b{width:30px;height:10px;background:green}</style><div id="outer"><div id="wrap"><div id="a">text</div></div><div id="b">other</div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut result := document_layout_result(document) or { panic('missing layout') }
	_ = record_retained_display_list(mut document) or { panic('missing paint') }
	mut target := document.get_element_by_id('a') or { panic('missing target') }
	target.set_attribute_value('class', 'lit')
	document.update_layout(.html_event_loop_rendering_update)
	_ = record_retained_display_list(mut document) or { panic('missing restyled paint') }
	sibling := subtree_refresh_box_for_id(document, result, 'b')
	document.update_animations_and_send_events(500)
	document.update_layout(.html_event_loop_rendering_update)
	sampled := record_retained_display_list(mut document) or { panic('missing sampled paint') }
	sampled_dump := sampled.dump()
	assert voidptr(subtree_refresh_box_for_id(document, result, 'b')) == voidptr(sibling)
	refresh_document_paint_tree(document, mut result, 320, 200)
	assert (record_retained_display_list(mut document) or { panic('missing full paint') }).dump() == sampled_dump
}
