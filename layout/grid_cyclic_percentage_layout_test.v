module layout

import html

fn test_auto_grid_resolves_percentage_rows_after_freezing_its_intrinsic_height() {
	for alignment in ['start', 'center', 'end'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0;font-size:0;line-height:0}#grid{display:inline-grid;position:relative;grid:50% / 70%;place-content:${alignment}}span{display:inline-block;height:20px}#first{width:60px}#last{width:40px}</style><div id="grid"><div id="item"><span id="first"></span><span id="last"></span></div></div>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 800, 600)
		grid := (document.get_element_by_id('grid') or { panic('grid') }).get_bounding_client_rect()
		item := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
		assert grid.width == 100 && grid.height == 40, '${grid.width},${grid.height}'
		assert item.width == 70 && item.height == 20, '${item.width},${item.height}'
		fraction := if alignment == 'center' {
			0.5
		} else if alignment == 'end' {
			1.0
		} else {
			0.0
		}
		assert item.x - grid.x == 30 * fraction
		assert item.y - grid.y == 20 * fraction
	}
}
