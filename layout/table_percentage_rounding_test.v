module layout

import html
import dom

fn test_table_percentage_guess_uses_chromium_layout_unit_truncation() {
	for mode in ['auto', 'fixed'] {
		for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
			mut document := html.parse_document('<!doctype html><style>body{margin:0}table{width:646px;border-spacing:0;table-layout:${mode}}td{border:0;padding:0}#first{width:40%}</style><table><tr><td id="first"><div style="width:1px;height:10px"></div></td><td><div style="width:1px;height:10px"></div></td><td><div style="width:1px;height:10px"></div></td></tr></table>')
			defer { document.finalize() }
			document.set_font_rendering_policy(policy)
			result := run_document_layout(document, 800, 600) or { panic('layout') }
			element := document.get_element_by_id('first') or { panic('first') }
			bridge := element.as_node().layout_node() or { panic('bridge') }
			node := unsafe { &Node(bridge.layout_handle) }
			used := result.used_values_for(node.as_node_with_style() or { panic('style') }) or { panic('used') }
			actual := used.content_width().raw_value()
			expected := if policy == .chromium { 16537 } else { 16538 }
			assert actual == expected
		}
	}
}
