module layout

import html

fn test_fixed_anchor_groups_ignore_the_device_layout_projection() {
	for density in [f64(1), 2] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}
			#top{position:fixed;left:10px;top:20px;width:80px;height:40px;background:red}
			#bottom{position:fixed;right:10px;bottom:20px;width:80px;height:40px;background:blue}
			#scaled{position:fixed;left:110px;top:20px;width:80px;height:40px;background:green;transform:scale(2)}
			</style><div id="top"></div><div id="bottom"></div><div id="scaled"></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		document.set_display_device_pixel_ratio(density)
		document.set_layout_coordinate_scale(density)
		_ = layout_document_typed_in_viewport(document, 400, 300)
		_ = document.record_display_list() or { panic('paint') }
		result := document_layout_result(document) or { panic('layout') }
		mut groups := map[string]int{}
		for entry in result.paint_order {
			box := entry.box
			if box.layout_handle == unsafe { nil } { continue }
			node := unsafe { &Node(box.layout_handle) }
			dom_node := node.dom_node() or { continue }
			element := dom_node.as_element() or { continue }
			id := element.get_attribute_value('id')
			if id in ['top', 'bottom', 'scaled'] {
				groups[id] = chromium_fixed_raster_group(box, node)
			}
		}
		assert groups['top'] == 1, 'density=${density}, groups=${groups}'
		assert groups['bottom'] == 4
		assert groups['scaled'] == 0
	}
}
