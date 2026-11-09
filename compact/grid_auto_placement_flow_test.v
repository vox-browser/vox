module main

import html
import layout

fn test_sparse_locked_grid_items_preserve_the_row_cursor_in_both_flow_directions() {
	for row_flow in [true, false] {
		for dense in [false, true] {
			flow := if row_flow { 'row' } else { 'column' }
			row_axis := if row_flow { 'row' } else { 'column' }
			column_axis := if row_flow { 'column' } else { 'row' }
			packing := if dense { 'dense' } else { '' }
			mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;grid-auto-flow:${flow} ${packing};grid-auto-columns:50px;grid-auto-rows:50px}#fixed{grid-${row_axis}:1;grid-${column_axis}:2}#span{grid-${row_axis}:1;grid-${column_axis}:span 2}#last{grid-${row_axis}:1}</style><div id="grid"><div id="fixed"></div><div id="span"></div><div id="last"></div><div id="auto"></div></div>')
			defer { document.finalize() }
			_ = layout.layout_document_typed_in_viewport(document, 800, 600)
			last := (document.get_element_by_id('last') or { panic('last') }).get_bounding_client_rect()
			expected := if dense { 0.0 } else { 200.0 }
			actual := if row_flow { last.x } else { last.y }
			assert actual == expected, '${flow} ${packing}: ${actual}'
			automatic := (document.get_element_by_id('auto') or { panic('auto') }).get_bounding_client_rect()
			if !dense {
				assert automatic.x == 0 && automatic.y == 0
			}
		}
	}
}

fn test_sparse_locked_item_cursors_belong_to_their_start_row() {
	for row_flow in [true,false] {
		flow := if row_flow { 'row' } else { 'column' }
		row_axis := if row_flow { 'row' } else { 'column' }
		column_axis := if row_flow { 'column' } else { 'row' }
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;grid-auto-flow:${flow};grid-auto-columns:50px;grid-auto-rows:50px}#fixed1{grid-${row_axis}:1;grid-${column_axis}:2}#fixed2{grid-${row_axis}:2;grid-${column_axis}:1}#span{grid-${row_axis}:1 / span 2}#other{grid-${row_axis}:2}</style><div id="grid"><div id="fixed1"></div><div id="fixed2"></div><div id="span"></div><div id="other"></div></div>')
		defer { document.finalize() }
		_ = layout.layout_document_typed_in_viewport(document,800,600)
		other := (document.get_element_by_id('other') or { panic('other') }).get_bounding_client_rect()
		actual := if row_flow { other.x } else { other.y }
		assert actual==50,'${flow}: ${actual}'
	}
}
