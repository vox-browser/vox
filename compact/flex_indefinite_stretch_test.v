module main

import html
import layout

fn test_indefinite_column_stretch_basis_behaves_as_content() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{display:flex;flex-direction:column;width:100px}#target{flex:0 1 stretch;min-height:0}#child{width:30px;height:50px}</style><div id="cb"><div id="target"><div id="child"></div></div></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
	assert r.height == 50, '${r.height}'
}

fn test_column_minimum_height_does_not_make_item_stretch_minimum_definite() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{display:flex;flex-direction:column;min-height:100px;width:200px;border:3px solid}#target{min-height:stretch;flex-basis:0;border:3px solid}</style><div id="cb"><div id="target">lorem ipsum</div></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
	assert r.height == 6, '${r.height}'
}
