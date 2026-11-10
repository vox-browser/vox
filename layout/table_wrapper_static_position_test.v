module layout

import html

// Ladybird a4c3e3e2ec8d7441d580fe9127bf37fec6ef042d.
fn test_absolute_table_static_position_keeps_its_original_display() {
	for alignment in ['center', 'right'] {
		for display in ['table', 'inline-table'] {
			mut document := html.parse_document('<!doctype html><style>
				body{margin:0;font-size:0;line-height:0}
				#container{position:relative;width:400px;height:20px;text-align:${alignment}}
				#target{position:absolute;display:${display};width:50px;height:10px}
			</style><div id="container"> x <div id="target"></div></div>')
			defer { document.finalize() }
			_ = layout_document_typed_in_viewport(document, 800, 600)
			container := (document.get_element_by_id('container') or { panic('container') }).get_bounding_client_rect()
			target := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
			expected := if display == 'table' {
				0.0
			} else if alignment == 'center' {
				200.0
			} else {
				400.0
			}
			assert target.x - container.x == expected, '${display}, ${alignment}: ${target.x - container.x}'
		}
	}
}
