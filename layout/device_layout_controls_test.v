module layout

import css
import html

fn test_device_layout_control_auto_sizes_use_the_projected_font_once() {
	mut logical_widths := map[string]f64{}
	for scale in [1.0, 2.0] {
		mut document := html.parse_document('<!doctype html><style>
			html,body{margin:0}input,textarea{font:16px/20px monospace}
			#search{font:13px Verdana;width:300px;box-sizing:border-box;padding:6px 25px 6px 9px;border:1px solid gray}
		</style><input id="text" size="10" placeholder="hint"><input id="search" placeholder="search"><input id="range" type="range"><textarea id="area" cols="10" rows="3"></textarea>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		document.set_layout_coordinate_scale(scale)
		result := run_document_layout(document, 800, 600) or { panic('layout') }
		for id in ['text', 'search', 'range', 'area'] {
			element := document.get_element_by_id(id) or { panic(id) }
			bridge := element.as_node().layout_node() or { panic('layout node') }
			node := unsafe { &Node(bridge.layout_handle) }
			box := node.as_box() or { panic('control box') }
			auto_size := box.auto_content_box_size()
			computed := node.computed_values()
			if id == 'range' {
				assert auto_size.height or { panic('range height') } == css.CSSPixels.nearest_value_for(16 * scale)
			} else {
				rows := if id == 'area' { 3 } else { 1 }
				assert auto_size.height or { panic('control height') } == computed.line_height().times_float(f64(rows))
			}
			columns := if id in ['text', 'area'] { 10 } else { 20 }
			width := auto_size.width or { panic('control width') }
			if id == 'range' {
				assert width == resolve_font_dependent_length_for_node(node, css.Length.new(f64(columns), .ch))
			} else if scale == 1 {
				logical_widths[id] = width.to_double()
			} else {
				assert width.to_double() / scale == logical_widths[id]
			}
			if id == 'search' {
				used := result.state.try_get(node.as_node_with_style() or { panic('style') }) or { panic('geometry') }
				assert used.content_height() == computed.line_height()
				assert element.get_bounding_client_rect().height == computed.line_height().to_double() / scale + 14
				assert element.get_bounding_client_rect().width == 300
			}
		}
	}
}
