module layout

import html

fn cyclic_max_node(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() {
		if found := cyclic_max_node(child, id) { return found }
	}
	return none
}

fn cyclic_max_width(result DocumentLayoutResult, id string) f64 {
	node := cyclic_max_node(result.root, id) or { panic('missing ${id}') }
	styled := node.as_node_with_style() or { panic('missing style') }
	values := result.used_values_for(styled) or { panic('missing geometry') }
	return values.content_width().to_double()
}

fn test_inline_percentage_maximum_does_not_erase_flex_intrinsic_content() {
	for width in [200, 50] {
		for maximum in ['100%', 'calc(100% - 2px)'] {
			document := html.parse_document('<!doctype html><style>
				#row{display:flex;width:${width}px;gap:10px}
				#icon{width:16px;flex:none}
				#item{overflow:hidden}
				#label{display:inline-block;max-width:${maximum};white-space:nowrap;overflow:hidden}
				#content{display:inline-block;width:60px;height:10px}
			</style><div id="row"><div id="icon"></div><div id="item"><div><span id="label"><span id="content"></span></span></div></div></div>')
			result := run_document_layout(document, 800, 600) or { panic('layout failed') }
			expected_item := if width == 200 { f64(60) } else { f64(24) }
			expected_label := expected_item - if maximum == '100%' { f64(0) } else { f64(2) }
			assert cyclic_max_width(result, 'item') == expected_item
			assert cyclic_max_width(result, 'label') == expected_label
			assert cyclic_max_width(result, 'content') == 60
		}
	}
}

fn test_inline_definite_percentage_maximum_and_minimum_still_apply() {
	document := html.parse_document('<!doctype html><style>
		.parent{width:40px}
		.label{display:inline-block;max-width:50%}
		.content{display:inline-block;width:60px;height:10px}
		#minimum{min-width:30px}
	</style><div class="parent"><span class="label" id="limited"><span class="content"></span></span></div><div class="parent"><span class="label" id="minimum"><span class="content"></span></span></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert cyclic_max_width(result, 'limited') == 20
	assert cyclic_max_width(result, 'minimum') == 30
}

fn test_inline_absolute_maximum_keeps_intrinsic_clamp_and_minimum_precedence() {
	document := html.parse_document('<!doctype html><style>
		.row{display:flex;width:200px}.item{overflow:hidden}
		.label{display:inline-block;max-width:10px}
		.content{display:inline-block;width:60px;height:10px}
		#minimum{min-width:20px}
	</style><div class="row"><div class="item" id="limited-item"><span class="label" id="limited"><span class="content"></span></span></div></div><div class="row"><div class="item" id="minimum-item"><span class="label" id="minimum"><span class="content"></span></span></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert cyclic_max_width(result, 'limited-item') == 10
	assert cyclic_max_width(result, 'limited') == 10
	assert cyclic_max_width(result, 'minimum-item') == 20
	assert cyclic_max_width(result, 'minimum') == 20
}

fn test_inline_cyclic_maximum_preserves_border_box_minimum() {
	document := html.parse_document('<!doctype html><style>
		#row{display:flex;width:200px}#item{overflow:hidden}
		#label{display:inline-block;max-width:100%;min-width:80px;box-sizing:border-box;padding:4px;border:1px solid}
		#content{display:inline-block;width:60px;height:10px}
	</style><div id="row"><div id="item"><span id="label"><span id="content"></span></span></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert cyclic_max_width(result, 'item') == 80
	assert cyclic_max_width(result, 'label') == 70
}
