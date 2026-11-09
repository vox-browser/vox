module layout

import html

fn test_replaced_auto_size_minimum_transfers_ratio_without_an_implicit_maximum() {
	for axis in ['width','height'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{position:absolute;min-${axis}:24px}</style><canvas id="target" width="16" height="16"></canvas>')
		defer { document.finalize() }
		run_document_layout(document,200,200) or { panic('layout') }
		r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
		assert r.width == 24 && r.height == 24,'${axis}: ${r.width}x${r.height}'
	}
}
