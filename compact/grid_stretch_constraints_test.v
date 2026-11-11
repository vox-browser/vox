module main

import html
import layout

fn test_grid_stretch_constraints_use_finished_rows_and_ignore_cyclic_track_constraints() {
	for example in [
		['grid-template-rows:35px;height:50px', 'height:0;min-height:stretch', '30'],
		['height:50px', 'height:55px;max-height:stretch', '65'],
	] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{display:grid;width:40px;${example[0]}}#target{${example[1]};margin-top:2px;margin-bottom:3px;border:3px solid;padding:2px}</style><div id="cb"><div id="target"></div></div>')
		_ = layout.layout_document_typed_in_viewport(document, 400, 300)
		r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
		assert r.height == example[2].f64(), '${example}: ${r.height}'
		document.finalize()
	}
}

fn test_grid_preferred_stretch_measures_content_when_the_row_is_automatic() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{display:grid}#target{height:stretch}#content{width:20px;height:20px}</style><div id="cb"><div id="target"><div id="content"></div></div></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
	assert r.height == 20, '${r.height}'
}
