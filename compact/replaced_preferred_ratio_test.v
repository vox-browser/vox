module main

import html
import layout

fn test_authored_replaced_ratio_overrides_the_natural_ratio_with_auto_dimensions() {
	for example in [
		['min-width:0', '15', '7.5'],
		['min-height:10px', '20', '10'],
		['max-width:10px', '10', '5'],
		['min-width:40px;max-height:10px', '40', '10'],
	] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}canvas{aspect-ratio:2;${example[0]}}</style><canvas id="target" width="15" height="15"></canvas>')
		_ = layout.layout_document_typed_in_viewport(document, 400, 300)
		r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
		assert r.width == example[1].f64(), '${example[0]}: ${r.width}'
		assert r.height == example[2].f64(), '${example[0]}: ${r.height}'
		document.finalize()
	}
}

fn test_replaced_intrinsic_width_constraints_use_the_stretched_opposite_axis() {
	for example in ['width:1px;min-width:fit-content', 'width:100px;max-width:fit-content'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{width:20px;height:20px;border:1px solid}canvas{height:stretch;${example}}</style><div id="cb"><canvas id="target" width="30" height="60"></canvas></div>')
		_ = layout.layout_document_typed_in_viewport(document, 400, 300)
		r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
		assert r.width == 10 && r.height == 20, '${example}: ${r.width} x ${r.height}'
		document.finalize()
	}
}
