module layout

import dom
import html

// Like upstream content-editable-toggle.html, buffer queries without unrelated
// DOM mutations. Exercise the caret-target facts on an inherited editable child.
fn test_live_editability_refreshes_retained_caret_targets() {
	document := html.parse_document('<!doctype html><style>html,body,p{margin:0}#target{width:100px;height:100px}</style><div id="host"><div id="target"></div></div><p>text below</p>')
	_ = layout_document_typed_in_viewport(document, 200, 200)
	mut mutable_document := unsafe { &dom.Document(document) }
	target := document.get_element_by_id('target') or { panic('missing target') }
	mut host := document.get_element_by_id('host') or { panic('missing host') }
	paintable := document.paintable_box() or { panic('missing viewport') }
	_ = paintable.hit_test(50, 50, .text_cursor)
	_ = mutable_document.record_display_list() or { panic('missing display list') }
	assert (paintable.hit_test(50, 50, .text_cursor) or { panic('missing hit') }).vertical_distance == none
	host.set_attribute_value('contenteditable', '')
	result := document_layout_result(document) or { panic('missing layout result') }
	assert !result.hit_test_display_list_is_valid
	position := mutable_document.caret_position_from_point(50, 50) or { panic('missing editable caret') }
	assert position.offset_node() == target.as_node()
	assert position.offset() == 0
	assert (paintable.hit_test(50, 50, .text_cursor) or { panic('missing hit') }).vertical_distance or { -1 } == 0
	host.remove_attribute('contenteditable')
	mutable_document.update_layout(.document_element_from_point)
	noneditable_paintable := document.paintable_box() or { panic('missing viewport') }
	assert (noneditable_paintable.hit_test(50, 50, .text_cursor) or { panic('missing hit') }).vertical_distance == none
	mutable_document.set_design_mode('on')!
	design_position := mutable_document.caret_position_from_point(50, 50) or { panic('missing designMode caret') }
	assert design_position.offset_node() == target.as_node()
	mutable_document.set_design_mode('off')!
	mutable_document.update_layout(.document_element_from_point)
	final_paintable := document.paintable_box() or { panic('missing viewport') }
	assert (final_paintable.hit_test(50, 50, .text_cursor) or { panic('missing hit') }).vertical_distance or { -1 } != 0
}

fn test_live_editing_host_change_relayouts_empty_text_even_when_its_flag_stays_true() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}#outer,#inner{font:20px/30px monospace}</style><div id="outer"><div id="inner" contenteditable></div></div>')
	mut outer := document.get_element_by_id('outer') or { panic('missing outer') }
	inner := document.get_element_by_id('inner') or { panic('missing inner') }
	text := document.create_text_node('')
	mut inner_node := inner.as_node()
	inner_node.append_child(text.as_node())!
	_ = layout_document_typed_in_viewport(document, 200, 200)
	mut mutable_document := unsafe { &dom.Document(document) }
	assert inner.get_bounding_client_rect().height == 30
	assert text.as_node().layout_node() != none
	assert inner_node.is_editing_host()
	outer.set_attribute_value('contenteditable', '')
	mutable_document.update_layout(.document_element_from_point)
	assert inner_node.in_editable_subtree()
	assert !inner_node.is_editing_host()
	assert inner.get_bounding_client_rect().height == 0
	outer.remove_attribute('contenteditable')
	mutable_document.update_layout(.document_element_from_point)
	assert inner.get_bounding_client_rect().height == 30
}

fn test_editability_changes_refresh_read_write_relational_and_sibling_selectors() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}#scope{width:80px}#scope:has(#leaf:read-write){width:140px}#peer{height:10px}#leaf:read-write + #peer{height:20px}</style><div id="scope"><div id="host"><div id="leaf"></div><div id="peer"></div></div></div>')
	mut host := document.get_element_by_id('host') or { panic('missing host') }
	scope := document.get_element_by_id('scope') or { panic('missing scope') }
	peer := document.get_element_by_id('peer') or { panic('missing peer') }
	_ = layout_document_typed_in_viewport(document, 200, 200)
	mut mutable_document := unsafe { &dom.Document(document) }
	assert scope.get_bounding_client_rect().width == 80
	assert peer.get_bounding_client_rect().height == 10
	host.set_attribute_value('contenteditable', '')
	mutable_document.update_layout(.document_element_from_point)
	assert scope.get_bounding_client_rect().width == 140
	assert peer.get_bounding_client_rect().height == 20
	host.remove_attribute('contenteditable')
	mutable_document.update_layout(.document_element_from_point)
	assert scope.get_bounding_client_rect().width == 80
	assert peer.get_bounding_client_rect().height == 10
	mutable_document.set_design_mode('on')!
	mutable_document.update_layout(.document_element_from_point)
	assert scope.get_bounding_client_rect().width == 140
	assert peer.get_bounding_client_rect().height == 20
	mutable_document.set_design_mode('off')!
	mutable_document.update_layout(.document_element_from_point)
	assert scope.get_bounding_client_rect().width == 80
	assert peer.get_bounding_client_rect().height == 10
}
