module layout

import html as html_parser

fn row_basis_test_node(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() {
		if found := row_basis_test_node(child, id) { return found }
	}
	return none
}

fn row_basis_test_used(result DocumentLayoutResult, id string) &UsedValues {
	node := row_basis_test_node(result.root, id) or { panic('missing #${id}') }
	styled := node.as_node_with_style() or { panic('unstyled #${id}') }
	return result.used_values_for(styled) or { panic('missing used values') }
}

fn test_nested_row_percentage_bases_keep_natural_height_and_used_width() {
	for direction in ['row', 'row-reverse'] {
		document := html_parser.parse_document('<!doctype html><style>body{margin:0}#outer{display:flex;width:240px;flex-direction:${direction}}#middle{display:flex;flex:1 1 0%;min-width:0}#leaf{flex:1 1 0%;min-width:0}#bar{height:20px;width:30px}</style><div id="outer"><div id="middle"><div id="leaf"><div id="bar"></div></div></div></div>')
		result := run_document_layout(document, 800, 600) or { panic('layout failed') }
		gc_collect()
		for id in ['outer', 'middle', 'leaf'] {
			assert row_basis_test_used(result, id).content_width().to_double() == 240
			assert row_basis_test_used(result, id).content_height().to_double() == 20
		}
		assert row_basis_test_used(result, 'bar').content_width().to_double() == 30
	}
}

fn test_row_percentage_basis_still_promotes_real_percentage_height_descendants() {
	document := html_parser.parse_document('<!doctype html><style>body{margin:0}#outer{display:flex;width:240px}#item{flex:1 1 0%;min-width:0}#percentage{height:50%}#bar{height:40px}</style><div id="outer"><div id="item"><div id="percentage"></div><div id="bar"></div></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert row_basis_test_used(result, 'outer').content_height().to_double() == 40
	assert row_basis_test_used(result, 'item').content_height().to_double() == 40
	assert row_basis_test_used(result, 'percentage').content_height().to_double() == 20
	item := row_basis_test_node(result.root, 'item') or { panic('missing item') }
	mut fresh := LayoutState.new()
	assert flex_subtree_depends_on_definite_height(mut fresh, item)
}

fn test_column_percentage_basis_keeps_its_definite_height_dependency() {
	for direction in ['column', 'column-reverse'] {
		document := html_parser.parse_document('<!doctype html><style>body{margin:0}#outer{display:flex;width:240px}#column{display:flex;flex-direction:${direction};flex:1 1 0%;min-width:0}#inner{flex:0 0 50%;min-height:0}#bar{height:20px}#spacer{width:20px;height:100px}</style><div id="outer"><div id="column"><div id="inner"><div id="bar"></div></div></div><div id="spacer"></div></div>')
		result := run_document_layout(document, 800, 600) or { panic('layout failed') }
		assert row_basis_test_used(result, 'outer').content_height().to_double() == 100
		assert row_basis_test_used(result, 'column').content_height().to_double() == 100
		assert row_basis_test_used(result, 'inner').content_height().to_double() == 50
		inner := row_basis_test_node(result.root, 'inner') or { panic('missing inner') }
		mut fresh := LayoutState.new()
		assert flex_subtree_depends_on_definite_height(mut fresh, inner)
	}
}

fn test_vertical_row_percentage_basis_keeps_dependency_with_horizontal_child() {
	document := html_parser.parse_document('<!doctype html><style>body{margin:0}#outer{display:flex;writing-mode:vertical-lr;width:120px;height:200px}#item{writing-mode:horizontal-tb;flex:0 0 50%}#bar{height:20px}</style><div id="outer"><div id="item"><div id="bar"></div></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item := row_basis_test_node(result.root, 'item') or { panic('missing item') }
	parent := item.parent() or { panic('missing parent') }
	assert item.computed_values().writing_mode() == .horizontal_tb
	assert parent.computed_values().writing_mode() == .vertical_lr
	mut fresh := LayoutState.new()
	assert flex_subtree_depends_on_definite_height(mut fresh, item)
}
