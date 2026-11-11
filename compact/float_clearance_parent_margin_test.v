module main

import html
import layout

fn test_clearance_uses_the_border_position_after_parent_margin_collapse() {
	for bordered in [false, true] {
		border := if bordered { 'border:1px solid' } else { '' }
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{width:100px;height:100px;${border}}#float{float:left;width:30px;height:30px}#target{height:stretch;width:90px;clear:both;margin-top:50px;border:3px solid}</style><div id="cb"><div id="float"></div><div id="target"></div></div>')
		document.set_font_rendering_policy(.chromium)
		_ = layout.layout_document_typed_in_viewport(document, 400, 300)
		cb := (document.get_element_by_id('cb') or { panic('cb') }).get_bounding_client_rect()
		target := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
		assert target.y - cb.y == if bordered { 51 } else { 30 }, '${border}: ${target.y - cb.y}'
		document.finalize()
	}
}

fn test_clearance_keeps_non_collapsing_margins_already_beyond_the_float() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#float{float:right;width:50px;height:40px}#target{clear:both;margin-top:60px;height:20px}</style><div style="height:10px"></div><div id="float"></div><div id="target"></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
	assert r.y == 70, '${r.y}'
}
