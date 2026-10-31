module layout

import dom
import html

fn chromium_column_distribution_values(result DocumentLayoutResult, id string) &UsedValues {
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

fn test_chromium_auto_columns_truncate_surplus_shares_and_assign_the_remainder_last() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for target in [60, 100] {
			for spacing in [0, 2] {
				for direction in ['ltr', 'rtl'] {
					outer := target + 4 * spacing
					mut document := html.parse_document('<!doctype html><style>
						body { margin:0 }
						table { width:${outer}px; border-spacing:${spacing}px; direction:${direction} }
						td { padding:0; border:0 }
					</style><table><tr>
						<td id="one"><div style="width:10px;height:10px"></div></td>
						<td id="two"><div style="width:20px;height:10px"></div></td>
						<td id="three"><div style="width:30px;height:10px"></div></td>
					</tr></table>')
					defer { document.finalize() }
					document.set_font_rendering_policy(policy)
					layout_document_typed_in_viewport(document, 400, 300)
					result := document_layout_result(document) or { panic('missing layout') }
					one := chromium_column_distribution_values(result, 'one')
					two := chromium_column_distribution_values(result, 'two')
					three := chromium_column_distribution_values(result, 'three')
					expected_one := if target == 60 {
						640
					} else if policy == .chromium {
						1066
					} else {
						1067
					}
					expected_two := if target == 60 { 1280 } else { 2133 }
					expected_three := if target == 60 {
						1920
					} else if policy == .chromium {
						3201
					} else {
						3200
					}
					assert one.content_width().raw_value() == expected_one
					assert two.content_width().raw_value() == expected_two
					assert three.content_width().raw_value() == expected_three
					assert one.content_width().plus(two.content_width()).plus(three.content_width()).raw_value() == target * 64
				}
			}
		}
	}
}
