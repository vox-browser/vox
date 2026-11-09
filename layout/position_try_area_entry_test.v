module layout

import html
import css

fn test_position_area_fallback_entry_uses_its_own_computed_area() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#container{position:relative;width:600px;height:300px}#anchor{position:relative;top:100px;left:100px;width:100px;height:100px;anchor-name:--a}#target{position-anchor:--a;position-try-fallbacks:right center;position:absolute;width:200px;height:100px;position-area:left center}</style><div id="container"><div id="anchor"></div><div id="target"></div></div>')
	defer { document.finalize() }
	for _ in 0..3 {
		result := run_document_layout(document,800,600) or { panic('layout') }
		target := document.get_element_by_id('target') or { panic('target') }
		r := target.get_bounding_client_rect()
		bridge := target.as_node().unsafe_layout_node() or { panic('bridge') }
		node := unsafe { &Node(bridge.real_layout_handle()) }
		retained := (node.as_box() or { panic('box') }).position_try_state_ or { panic('state') }
		area := position_try_property_text(node.computed_values(),.position_area)
		assert r.x == 200,'x=${r.x},area=${area},option=${retained.current_option},success=${retained.current_success}'
		commit_position_try_options_in_subtree(unsafe { &Node(result.root) })
	}
}
