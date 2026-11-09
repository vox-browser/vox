module main

import html
import layout

fn test_absolute_stretch_auto_insets_begin_at_the_static_content_position() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{position:relative;width:40px;height:50px;padding:5px;border:2px solid}#target{position:absolute;width:20px;height:stretch;margin-top:2px;margin-bottom:3px;border:3px solid;padding:2px}</style><div id="cb"><div id="target"></div></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
	assert r.height == 50, '${r.height}'
}

fn test_flex_stretch_keyword_uses_the_final_line_cross_size() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{display:inline-flex;flex-flow:row wrap;width:40px;height:50px}#target{width:20px;height:stretch;margin-top:2px;margin-bottom:3px;border:3px solid;padding:2px}#tall{height:60px;width:0}</style><div id="cb"><div id="target"></div><div id="tall"></div></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
	assert r.height == 55, '${r.height}'
}
