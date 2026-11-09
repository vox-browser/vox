module layout

import html

fn test_inline_negative_margins_reduce_the_width_used_for_line_fitting() {
	for inner in ['123 <span style="margin-left:-8ch">1234 </span>','123 <span style="margin-left:-8ch">123 </span>','<span style="display:inline-block;width:5ch;height:0"></span><span style="margin-left:-5ch">123</span>'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0;font:10px/10px monospace}#target{display:inline-block;max-width:4ch}</style><div id="target">${inner}</div>')
		defer { document.finalize() }
		result := run_document_layout(document,300,200) or { panic('layout') }
		target := document.get_element_by_id('target') or { panic('target') }
		bridge := target.as_node().unsafe_layout_node() or { panic('bridge') }
		node := unsafe { &Node(bridge.real_layout_handle()) }
		used := result.used_values_for(node.as_node_with_style() or { panic('style') }) or { panic('values') }
		assert used.line_boxes.len == 1,'${inner}: ${used.line_boxes.len} lines'
	}
}
