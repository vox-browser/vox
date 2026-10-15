module layout

import html as html_parser

fn inside_height_test_node(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() {
		if found := inside_height_test_node(child, id) { return found }
	}
	return none
}

fn inside_height_test_used(result DocumentLayoutResult, id string) &UsedValues {
	node := inside_height_test_node(result.root, id) or { panic('missing #${id}') }
	styled := node.as_node_with_style() or { panic('unstyled #${id}') }
	return result.used_values_for(styled) or { panic('missing used values') }
}

fn test_flex_own_percentage_constraints_keep_fixed_geometry_without_height_consumers() {
	for constraint in ['height:50%', 'height:100%', 'min-height:100%', 'max-height:100%'] {
		document := html_parser.parse_document('<!doctype html><style>body{margin:0}#outer{display:flex;width:240px}#item{display:flex;flex:1 1 auto;${constraint}}#deep{display:flex;flex:1 1 auto}#bar{height:20px;width:30px}</style><div id="outer"><div id="item"><div id="deep"><div id="bar"></div></div></div></div>')
		result := run_document_layout(document, 800, 600) or { panic('layout failed') }
		gc_collect()
		for id in ['outer', 'item', 'deep'] {
			assert inside_height_test_used(result, id).content_width().to_double() == 240
			assert inside_height_test_used(result, id).content_height().to_double() == 20
		}
		assert inside_height_test_used(result, 'bar').content_height().to_double() == 20
	}
}

fn test_flex_own_percentage_height_preserves_real_descendant_percentage_resolution() {
	document := html_parser.parse_document('<!doctype html><style>body{margin:0}#outer{display:flex;width:240px}#item{display:flex;flex:1 1 auto;height:100%}#percentage{height:50%;width:10px}#bar{height:20px;width:30px}</style><div id="outer"><div id="item"><div id="percentage"></div><div id="bar"></div></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert inside_height_test_used(result, 'item').content_height().to_double() == 20
	assert inside_height_test_used(result, 'percentage').content_height().to_double() == 10
	assert inside_height_test_used(result, 'bar').content_height().to_double() == 20
}

fn test_flex_own_percentage_minimum_still_relays_changed_stretched_height() {
	document := html_parser.parse_document('<!doctype html><style>body{margin:0}#outer{display:flex;width:240px}#item{display:flex;flex:1 1 auto;min-height:100%}#fill{flex:1 1 auto}#bar{height:20px;width:30px}#spacer{height:80px;width:20px}</style><div id="outer"><div id="item"><div id="fill"><div id="bar"></div></div></div><div id="spacer"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert inside_height_test_used(result, 'outer').content_height().to_double() == 80
	assert inside_height_test_used(result, 'item').content_height().to_double() == 80
	assert inside_height_test_used(result, 'fill').content_height().to_double() == 80
	assert inside_height_test_used(result, 'bar').content_height().to_double() == 20
}

fn test_flex_own_percentage_height_keeps_column_descendant_basis_and_baseline() {
	document := html_parser.parse_document('<!doctype html><style>body{margin:0;font:16px/20px monospace}#outer{display:flex;width:240px}#item{display:flex;flex-direction:column;flex:1 1 auto;height:100%}#part{flex:0 0 50%;min-height:0}#text{height:20px}#spacer{height:80px;width:20px}</style><div id="outer"><div id="item"><div id="part"><div id="text">A</div></div></div><div id="spacer"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item := inside_height_test_node(result.root, 'item') or { panic('missing item') }
	part := inside_height_test_node(result.root, 'part') or { panic('missing part') }
	mut state := result.state
	assert flex_subtree_depends_on_definite_height(mut state, part)
	assert inside_height_test_used(result, 'item').content_height().to_double() == 20
	assert inside_height_test_used(result, 'part').content_height().to_double() == 10
	assert layout_box_baseline(result.state, item, .first).to_double() > 0
}
