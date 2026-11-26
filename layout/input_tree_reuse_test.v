module layout

import dom
import html
import os

fn input_tree_handle(document &dom.Document, id string) voidptr {
	element := document.get_element_by_id(id) or { panic(id) }
	node := element.as_node()
	mirror := node.unsafe_layout_node() or { panic('layout') }
	return mirror.real_layout_handle()
}

fn input_tree_update_sibling(mut document dom.Document, text string) {
	mut changed := document.get_element_by_id('changed') or { panic('changed') }
	changed.set_inner_html('<p>${text}</p>') or { panic(err) }
	document.update_layout(.debugging)
}

fn input_tree_matches_full_rebuild(mut document dom.Document) {
	before := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('full paint') }).dump() == before
}

// A text input whose attributes and style are unchanged keeps its boxes, and
// its ancestors theirs, across a layout tree update elsewhere; a changed
// placeholder or value still shows.
fn test_unchanged_text_inputs_keep_their_boxes() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:16px/20px sans-serif}</style><body><div id="changed"></div><section id="stable"><p>Label <input id="field" type="text" placeholder="Search"></p></section></body>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	keeps := os.getenv('VOX_RETAIN_INPUT_TREE_REBUILDS') == ''
	for index in 0 .. 2 {
		stable := input_tree_handle(document, 'stable')
		field := input_tree_handle(document, 'field')
		input_tree_update_sibling(mut document, 'changed ${index}')
		assert (input_tree_handle(document, 'stable') == stable) == keeps, 'pass ${index}'
		assert (input_tree_handle(document, 'field') == field) == keeps, 'pass ${index}'
		input_tree_matches_full_rebuild(mut document)
	}
	mut input := document.get_element_by_id('field') or { panic('field') }
	for name, value in {
		'placeholder': 'Find a file'
		'value':       'typed text'
	} {
		input.set_attribute_value(name, value)
		document.update_layout(.debugging)
		input_tree_update_sibling(mut document, name)
		input_tree_matches_full_rebuild(mut document)
	}
}
