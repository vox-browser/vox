module layout

import html

fn baseline_cross_node(root &Node, id string) ?&Node {
	if element := (root.dom_node() or { return none }).as_element() {
		if element.get_attribute_value('id') == id { return root }
	}
	for child in root.children() { if found := baseline_cross_node(child, id) { return found } }
	return none
}

fn test_row_flex_lines_enclose_both_sides_of_aligned_baselines() {
	for wrap in ['nowrap', 'wrap'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#row{display:flex;align-items:baseline;flex-wrap:${wrap};width:200px}#a,#b{width:40px;line-height:20px}#a{font:20px/20px Arial}#b{font:10px/20px Arial}</style><div id="row"><div id="a">A</div><div id="b">B</div></div><div id="after">After</div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		result := run_document_layout(document, 400, 300) or { panic('layout') }
		row := baseline_cross_node(result.root, 'row') or { panic('row') }
		a := baseline_cross_node(result.root, 'a') or { panic('a') }
		b := baseline_cross_node(result.root, 'b') or { panic('b') }
		r := result.state.get(row.as_node_with_style() or { panic('row style') })
		av := result.state.get(a.as_node_with_style() or { panic('a style') })
		bv := result.state.get(b.as_node_with_style() or { panic('b style') })
		assert r.content_height().to_double() == 24
		assert av.offset.y().to_double() == 0
		assert bv.offset.y().to_double() == 4
	}
}

fn test_auto_cross_margin_items_do_not_raise_the_shared_baseline() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#row{display:flex;align-items:baseline;width:200px}#a{font:10px/20px Arial}#b{font:20px/20px Arial;margin-top:auto}</style><div id="row"><div id="a">A</div><div id="b">B</div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 400, 300) or { panic('layout') }
	row := baseline_cross_node(result.root, 'row') or { panic('row') }
	a := baseline_cross_node(result.root, 'a') or { panic('a') }
	r := result.state.get(row.as_node_with_style() or { panic('row style') })
	av := result.state.get(a.as_node_with_style() or { panic('a style') })
	assert r.content_height().to_double() == 20
	assert av.offset.y().to_double() == 0
}
