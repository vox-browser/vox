module layout

import dom
import html

fn chromium_definite_basis_values(result DocumentLayoutResult, id string) &UsedValues {
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

fn test_chromium_definite_flex_basis_keeps_its_main_size_after_cross_axis_constraints() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for explicit_basis in [false, true] {
			for column in [false, true] {
				main_property := if column { 'height' } else { 'width' }
				cross_property := if column { 'width' } else { 'height' }
				basis := if explicit_basis { 'flex:0 0 100px' } else { '${main_property}:100px;flex:none' }
				direction := if column { 'column' } else { 'row' }
				mut document := html.parse_document('<!doctype html><style>
					body { margin:0 }
					#flex { display:flex; flex-direction:${direction}; align-items:flex-start; width:300px; height:300px }
					#item { ${basis}; max-${cross_property}:40px }
				</style><div id="flex"><canvas id="item" width="100" height="100"></canvas></div>')
				defer { document.finalize() }
				document.set_font_rendering_policy(policy)
				layout_document_typed_in_viewport(document, 400, 400)
				result := document_layout_result(document) or { panic('missing layout') }
				item := chromium_definite_basis_values(result, 'item')
				main := if column { item.content_height() } else { item.content_width() }
				cross := if column { item.content_width() } else { item.content_height() }
				expected_main := if policy == .chromium { 100 } else { 40 }
				assert main.to_double() == expected_main
				assert cross.to_double() == 40
			}
		}
	}
}
