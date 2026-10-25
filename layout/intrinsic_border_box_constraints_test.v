module layout

import html

fn intrinsic_border_box_node(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id {
				return root
			}
		}
	}
	for child in root.children() {
		if found := intrinsic_border_box_node(child, id) {
			return found
		}
	}
	return none
}

fn intrinsic_border_box_values(result &DocumentLayoutResult, id string) &UsedValues {
	node := intrinsic_border_box_node(result.root, id) or { panic('missing ${id}') }
	styled := node.as_node_with_style() or { panic('missing style') }
	return result.used_values_for(styled) or { panic('missing geometry') }
}

// A shrink-wrapped ancestor consumes the child's outer contribution. The
// child's border-box maximum already includes its padding and borders.
fn test_shrink_wrapped_ancestors_apply_child_border_box_maximum_once() {
	for wrapper in ['position:absolute', 'display:inline-block', 'float:left', 'width:max-content'] {
		for sizing in ['border-box', 'content-box'] {
			mut document := html.parse_document('<!doctype html><style>
				#popup{${wrapper}}
				#tooltip{box-sizing:${sizing};max-width:calc(180px + 20px);padding:12px 16px;border:2px solid}
				#content{width:500px;height:10px}
			</style><div id="popup"><div><div id="tooltip"><div id="content"></div></div></div></div>')
			defer { document.finalize() }
			result := run_document_layout(document, 800, 600) or { panic('layout failed') }
			expected := if sizing == 'border-box' { f64(200) } else { f64(236) }
			assert intrinsic_border_box_values(&result, 'popup').content_width().to_double() == expected
			assert intrinsic_border_box_values(&result, 'tooltip').border_box_width().to_double() == expected
		}
	}
}

fn test_shrink_wrapped_border_box_minimum_and_minimum_precedence() {
	for limits in ['min-width:200px', 'min-width:200px;max-width:100px'] {
		mut document := html.parse_document('<!doctype html><style>
			#popup{position:absolute}
			#tooltip{box-sizing:border-box;${limits};padding:12px 16px;border:2px solid}
			#content{width:10px;height:10px}
		</style><div id="popup"><div id="tooltip"><div id="content"></div></div></div>')
		defer { document.finalize() }
		result := run_document_layout(document, 800, 600) or { panic('layout failed') }
		assert intrinsic_border_box_values(&result, 'popup').content_width().to_double() == 200
		assert intrinsic_border_box_values(&result, 'tooltip').content_width().to_double() == 164
	}
}

fn test_border_box_intrinsic_maximum_cannot_remove_border_and_padding() {
	mut document := html.parse_document('<!doctype html><style>
		#popup{position:absolute}
		#tooltip{box-sizing:border-box;max-width:10px;padding:12px 16px;border:2px solid;margin:0 7px}
		#content{width:500px;height:10px}
	</style><div id="popup"><div id="tooltip"><div id="content"></div></div></div>')
	defer { document.finalize() }
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert intrinsic_border_box_values(&result, 'popup').content_width().to_double() == 50
	assert intrinsic_border_box_values(&result, 'tooltip').content_width().to_double() == 0
	assert intrinsic_border_box_values(&result, 'tooltip').border_box_width().to_double() == 36
}
