module layout

import html
import dom

fn chromium_table_border_values(result DocumentLayoutResult, id string) &UsedValues {
	mut pending := [result.root]
	for pending.len > 0 {
		node := pending.pop()
		if dom_node := node.dom_node() {
			if element := dom_node.as_element() {
				if element.get_attribute_value('id') == id {
					styled := node.as_node_with_style() or { panic('missing style') }
					return result.used_values_for(styled) or { panic('missing geometry') }
				}
			}
		}
		for child in node.children() { pending << child }
	}
	panic('missing #${id}')
}

fn test_chromium_collapsed_table_borders_keep_fractional_shares_during_layout() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for border in [1, 3, 5] {
			mut document := html.parse_document('<!doctype html><style>
				table { width:100px; border-collapse:collapse; table-layout:fixed; border:${border}px solid }
				td { height:10px; padding:0; border:${border}px solid; vertical-align:top }
			</style><table id="table"><tr><td id="cell"></td></tr></table>')
			defer { document.finalize() }
			document.set_font_rendering_policy(policy)
			for _ in 0 .. 2 {
				layout_document_typed_in_viewport(document, 800, 600)
				result := document_layout_result(document) or { panic('missing layout') }
				table := chromium_table_border_values(result, 'table')
				cell := chromium_table_border_values(result, 'cell')
				before := if policy == .chromium { f64(border) / 2 } else { f64((border + 1) / 2) }
				after := if policy == .chromium { f64(border) / 2 } else { f64(border / 2) }
				assert table.border_left_collapsed().to_double() == before
				assert table.border_right_collapsed().to_double() == after
				assert table.border_top_collapsed().to_double() == before
				assert cell.border_left_collapsed().to_double() == after
				assert cell.border_right_collapsed().to_double() == before
				assert table.offset.x().to_double() == before
				assert table.border_box_width().to_double() == 100
				assert cell.content_width().to_double() == 100 - 2 * border
				assert table_cell_content_offset_left(*cell, true).to_double() == after
				assert table_cell_content_offset_top(*cell, true).to_double() == after
			}
		}
	}
}
