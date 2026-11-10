module layout

import dom
import html

fn outside_marker_node_with_id(root &Node, id string) ?&Node {
	if source := root.dom_node() {
		if element := source.as_element() {
			if element.get_attribute_value('id') == id {
				return root
			}
		}
	}
	for child in root.children() {
		if found := outside_marker_node_with_id(child, id) {
			return found
		}
	}
	return none
}

fn outside_marker_inline_offset(result DocumentLayoutResult, id string) f64 {
	node := outside_marker_node_with_id(result.root, id) or { panic('missing list item') }
	item := node.as_list_item_box() or { panic('not a list item') }
	marker := item.marker() or { panic('missing marker') }
	style := marker.as_node_with_style() or { panic('missing marker style') }
	used := result.used_values_for(style) or { panic('missing marker layout') }
	return used.offset.x().to_double()
}

fn test_outside_list_markers_follow_the_border_edge_with_padding_and_borders() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for direction in ['ltr', 'rtl'] {
			mut document := html.parse_document('<!doctype html><style>
				li { direction:${direction}; width:100px; list-style-type:decimal }
				#padded { padding-left:30px; border-left:5px solid; padding-right:40px; border-right:7px solid }
			</style><ol><li id="base" value="1">text</li><li id="padded" value="1">text</li></ol>')
			defer { document.finalize() }
			document.set_font_rendering_policy(policy)
			result := run_document_layout(document, 400, 200) or { panic('layout failed') }
			shift := outside_marker_inline_offset(result, 'padded') - outside_marker_inline_offset(result, 'base')
			assert shift == if direction == 'ltr' { -35.0 } else { 47.0 }
		}
	}
}

fn test_chromium_outside_symbol_markers_follow_the_border_edge() {
	mut document := html.parse_document('<!doctype html><style>
		li { width:100px; list-style-type:disc }
		#padded { padding-left:30px; border-left:5px solid }
	</style><ul><li id="base">text</li><li id="padded">text</li></ul>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 400, 200) or { panic('layout failed') }
	assert outside_marker_inline_offset(result, 'padded') - outside_marker_inline_offset(result, 'base') == -35
}
