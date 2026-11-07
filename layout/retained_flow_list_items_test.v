module layout

import dom
import html

fn list_flow_handle(element &dom.Element) voidptr {
	return element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()
}

fn list_flow_check_full_rebuild(mut document dom.Document) {
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing full paint') }).dump() == before
}

fn list_flow_rebuild_elsewhere(mut document dom.Document, index int) {
	mut changed := document.get_element_by_id('changed') or { panic('missing changed') }
	changed.set_inner_html('<p>new branch ${index}</p>') or { panic(err) }
	document.update_layout(.debugging)
}

fn test_bullet_list_items_keep_their_boxes_across_rebuilds() {
	for style in ['', 'list-style-type:circle', 'list-style-type:square', 'list-style-type:none', 'list-style-type:"- "', 'list-style-position:inside'] {
		mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable"><ul style="${style}"><li>first</li><li>second <b>bold</b></li><li id="last">third</li></ul></section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		stable := document.get_element_by_id('stable')?
		last := document.get_element_by_id('last')?
		for index in 0 .. 2 {
			before := list_flow_handle(stable)
			item := list_flow_handle(last)
			list_flow_rebuild_elsewhere(mut document, index)
			assert list_flow_handle(stable) == before
			assert list_flow_handle(last) == item
		}
		list_flow_check_full_rebuild(mut document)
	}
}

fn test_ordinal_and_authored_markers_are_rebuilt() {
	for list in ['<ol><li id="last">a</li></ol>', '<ul style="list-style-type:lower-roman"><li id="last">a</li></ul>',
		'<style>li::marker{content:counter(list-item) ". "}</style><ul><li id="last">a</li></ul>'] {
		mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable">${list}</section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		last := document.get_element_by_id('last')?
		item := list_flow_handle(last)
		list_flow_rebuild_elsewhere(mut document, 0)
		assert list_flow_handle(last) != item
		list_flow_check_full_rebuild(mut document)
	}
}

fn test_restyled_marker_rebuilds_its_list_item() {
	mut document := html.parse_document('<!doctype html><style>.red li::marker{color:red}</style><div id="changed"></div><section id="stable"><ul id="list"><li id="last">a</li></ul></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	last := document.get_element_by_id('last')?
	item := list_flow_handle(last)
	mut list := document.get_element_by_id('list')?
	list.set_attribute_value('class', 'red')
	list_flow_rebuild_elsewhere(mut document, 0)
	recording := document.record_display_list()?
	assert display_list_commands(recording).len > 0
	list_flow_check_full_rebuild(mut document)
	_ = item
}
