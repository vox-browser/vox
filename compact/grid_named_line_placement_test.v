module main

import html
import layout

fn test_grid_named_line_occurrences_search_from_the_requested_edge_and_extend_implicitly() {
	for index, placement in ['-2 a', '2 missing', '1 / span missing', 'span missing / 1'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;grid-template-columns:[a] 50px [a] 100px [a];grid-auto-columns:10px}#item{grid-column:${placement};height:10px}</style><div id="grid"><div id="item"></div></div>')
		defer { document.finalize() }
		_ = layout.layout_document_typed_in_viewport(document, 800, 600)
		item := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
		assert item.x == [50.0, 170.0, 0.0, 0.0][index], '${placement}: x ${item.x}'
		assert item.width == [100.0, 10.0, 160.0, 10.0][index], '${placement}: width ${item.width}'
	}
}

fn test_automatic_named_spans_without_an_anchor_are_one_track() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;grid-template-columns:repeat(6,50px)}#item{grid-column:span 2 missing;height:10px}</style><div id="grid"><div id="item"></div></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	item := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
	assert item.width == 50
}
