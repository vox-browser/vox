module main

import html
import layout

fn test_auto_repeat_maximum_border_box_counts_use_resolved_inline_percentage_padding_on_both_axes() {
	for size in ['auto', 'min-content', 'max-content'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#parent{width:min-content}#grid{display:grid;position:relative;grid:repeat(auto-fill,50px) / repeat(auto-fill,100px);max-width:300px;max-height:200px;box-sizing:border-box;padding:10%;width:${size};height:${size}}#item{grid-column:-2;grid-row:-2}</style><div id="parent"><div id="grid"><div id="item"></div></div></div>')
		defer { document.finalize() }
		_ = layout.layout_document_typed_in_viewport(document, 800, 600)
		grid := (document.get_element_by_id('grid') or { panic('grid') }).get_bounding_client_rect()
		item := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
		assert grid.height == 160, '${size}: height ${grid.height}'
		assert grid.width == if size=='auto' { 300 } else { 260 }, '${size}: width ${grid.width}'
		assert item.x-grid.x==130,'${size}: item x ${item.x-grid.x}'
		assert item.y - grid.y == 80, '${size}: item y ${item.y - grid.y}'
	}
}
