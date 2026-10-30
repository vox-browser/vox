module layout

import html

fn empty_margin_node(root &Node, id string) ?&Node {
	if owner := root.dom_node() {
		if element := owner.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() {
		if found := empty_margin_node(child, id) { return found }
	}
	return none
}

fn empty_margin_used(result DocumentLayoutResult, id string) &UsedValues {
	node := empty_margin_node(result.root, id) or { panic('missing ${id}') }
	return result.used_values_for(node.as_node_with_style() or { panic('missing style') }) or {
		panic('missing geometry')
	}
}

fn test_formatting_context_height_consumes_collapsed_empty_margins_once() {
	for contents, expected in {
		'<p>Text</p><p></p>':                             f64(48)
		'<p>Text</p><p class="large"></p>':               f64(66)
		'<p class="large"></p>':                          f64(30)
		'<p>Text</p><p></p><p></p>':                      f64(48)
		'<p></p><p>Text</p>':                             f64(48)
		'<p>Text</p><p style="border:1px solid"></p>':    f64(62)
		'<div class="plain"></div><p class="mixed"></p>': f64(39)
		'<p class="mixed"></p>':                          f64(15)
		'<p class="negative"></p>':                       f64(0)
		'<p>Text</p><div><p class="large"></p></div>':    f64(66)
	} {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0;font:16px/24px Arial}#box{display:flow-root;padding:20px;border:1px solid}
			p{margin:12px 0}.large{margin:30px 0}.plain{height:24px}
			.mixed{margin:20px 0 -5px}.negative{margin:-12px 0}
		</style><div id="box">${contents}</div>')
		defer { document.finalize() }
		result := run_document_layout(document, 800, 600) or { panic('missing layout') }
		used := empty_margin_used(result, 'box')
		assert used.content_height().to_double() == expected, contents
	}
}

fn test_grid_intrinsic_rows_use_the_same_collapsed_empty_margin_height() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0;font:16px/24px Arial}.grid{display:grid;grid-template-columns:350px;gap:15px}
		.card{padding:20px;border:1px solid}p{margin:12px 0}
	</style><div class="grid" id="grid"><div class="card"><p>Text</p><p></p></div>
	<div class="card" id="second"><p>Text</p></div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 800, 600) or { panic('missing layout') }
	assert empty_margin_used(result, 'grid').content_height().to_double() == 195
	second := empty_margin_used(result, 'second')
	assert second.offset.y().minus(second.border_box_top()).to_double() == 105
}
