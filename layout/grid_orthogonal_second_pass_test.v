module layout

import html

fn test_grid_remeasures_orthogonal_content_after_rows_constrain_its_inline_axis() {
	for alignment in ['start', 'center', 'end'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0;font-size:0;line-height:0}#grid{display:grid;width:100px;height:50px;justify-content:${alignment}}#item{writing-mode:vertical-lr}span{display:inline-block;width:25px}#first{height:50px}#last{height:25px}</style><div id="grid"><div id="item"><span id="first"></span><span id="last"></span></div></div>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 800, 600)
		item := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
		assert item.width == 50 && item.height == 50, '${item.width},${item.height}'
		expected := if alignment == 'center' {
			25.0
		} else if alignment == 'end' {
			50.0
		} else {
			0.0
		}
		assert item.x == expected
	}
}
