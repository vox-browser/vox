module layout

import html

fn test_svg_paint_path_rounds_relative_coordinates_before_the_next_segment() {
	for chromium in [true, false] {
		mut document := html.parse_document('<!doctype html><svg width="100" height="100"><path d="M40.1 30.3 l.1 .2 .1 .2 Z" fill="red"/></svg>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		_ = layout_document_typed_in_viewport(document, 120, 120)
		commands := display_list_commands(document.record_display_list() or {
			panic('missing SVG recording')
		}).filter(it.kind == 'draw_svg_path')
		assert commands.len == 1
		data := commands[0].svg().path_data
		assert data.len == 48
		assert data[13] == if chromium { f32(40.19999694824219) } else { f32(40.20000076293945) }
		assert data[25] == if chromium { f32(40.29999542236328) } else { f32(40.29999923706055) }
	}
}

fn precision_path_node(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() {
		if found := precision_path_node(child, id) { return found }
	}
	return none
}

fn test_svg_clipping_uses_the_same_relative_path_precision_as_painted_shapes() {
	for chromium in [true, false] {
		mut document := html.parse_document('<!doctype html><svg width="100" height="100"><defs><clipPath id="clip"><path d="M40.1 30.3 l.1 .2 .1 .2 Z"/></clipPath></defs><g id="target" clip-path="url(#clip)"><rect width="100" height="100"/></g></svg>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		result := run_document_layout(document, 120, 120) or { panic('missing layout') }
		target := precision_path_node(result.root, 'target') or { panic('missing target') }
		used := result.used_values_for(target.as_node_with_style() or { panic('missing style') }) or { panic('missing values') }
		clip := svg_url_clip_path_for_box(target, result.state, used) or { panic('missing clip') }
		assert clip.components.len == 1
		point := clip.components[0].path.segments[1].point
		assert point.x == if chromium { 40.19999694824219 } else { 40.2 }
	}
}

fn test_svg_mask_images_inherit_the_embedding_documents_path_precision() {
	for chromium in [true, false] {
		mut document := html.parse_document('<!doctype html><style>#target{width:100px;height:100px;background:red;mask-image:url("data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' viewBox=\'0 0 100 100\'%3E%3Cpath d=\'M40.1 30.3 l.1 .2 .1 .2 Z\'/%3E%3C/svg%3E");mask-size:100%}</style><div id="target"></div>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		root := layout_document_typed_in_viewport(document, 120, 120)
		element := document.get_element_by_id('target') or { panic('missing target') }
		box := root.find_box(i64(element.as_node().unique_id())) or { panic('missing box') }
		mask := box.clips().svg_mask or { panic('missing mask') }
		assert mask.operations.len == 1
		point := mask.operations[0].path.segments[1].point
		assert point.x == if chromium { 40.19999694824219 } else { 40.2 }
	}
}
