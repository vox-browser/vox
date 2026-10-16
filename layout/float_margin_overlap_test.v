module layout

import html

fn float_margin_overlap_node(root &Node, id string) ?&Node {
	if owner := root.dom_node() {
		if element := owner.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() {
		if found := float_margin_overlap_node(child, id) { return found }
	}
	return none
}

fn float_margin_overlap_used(result DocumentLayoutResult, id string) &UsedValues {
	node := float_margin_overlap_node(result.root, id) or { panic('missing ${id}') }
	return result.used_values_for(node.as_node_with_style() or { panic('missing style') }) or { panic('missing geometry') }
}

fn test_formatting_context_margins_overlap_the_float_intrusion_on_their_own_side() {
	for side in ['left', 'right'] {
		for margin in [3, 100, 120, -5, 0] {
			document := html.parse_document('<!doctype html><style>
				body{margin:0;width:400px}.float{float:${side};width:100px;height:20px}
				#box{overflow:hidden;height:10px;margin-${side}:${margin}px}
			</style><div class="float"></div><div id="box"></div>')
			result := run_document_layout(document, 800, 600) or { panic('missing layout') }
			used := float_margin_overlap_used(result, 'box')
			expected := if margin > 100 { f64(400 - margin) } else { f64(300) }
			assert used.content_width().to_double() == expected, '${side} margin ${margin}'
			expected_x := if side == 'left' && margin > 100 { f64(margin) }
				else if side == 'left' { f64(100) } else { f64(0) }
			assert used.offset.x().to_double() == expected_x
			assert used.offset.y().to_double() == 0
		}
	}
}

fn test_opposite_margin_and_border_padding_still_reduce_the_space_next_to_floats() {
	document := html.parse_document('<!doctype html><style>
		body{margin:0;width:400px}.float{float:left;width:100px;height:20px}
		#box{overflow:hidden;height:10px;margin-left:3px;margin-right:10px;padding:4px;border:1px solid}
	</style><div class="float"></div><div id="box"></div>')
	result := run_document_layout(document, 800, 600) or { panic('missing layout') }
	used := float_margin_overlap_used(result, 'box')
	assert used.offset.x().to_double() == 105
	assert used.content_width().to_double() == 280
	assert used.border_box_width().to_double() == 290
}

fn test_formatting_context_without_intruding_floats_retains_its_full_margins() {
	document := html.parse_document('<!doctype html><style>
		body{margin:0;width:400px}#box{overflow:hidden;height:10px;margin-left:3px;margin-right:10px}
	</style><div id="box"></div>')
	result := run_document_layout(document, 800, 600) or { panic('missing layout') }
	used := float_margin_overlap_used(result, 'box')
	assert used.offset.x().to_double() == 3
	assert used.content_width().to_double() == 387
}
