module layout

import html

fn chromium_inline_baseline_node(root &Node, id string) ?&Node {
	if node := root.dom_node() {
		if element := node.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() {
		if found := chromium_inline_baseline_node(child, id) { return found }
	}
	return none
}

fn test_chromium_inline_block_propagates_a_nested_block_flex_first_baseline() {
	$if !darwin { return }
	mut document := html.parse_document('<!doctype html><style>
		body { margin:0; font:16px/40px Arial }
		#outer { width:300px }
		#inline { display:inline-block; width:300px }
		#block { display:list-item; list-style:none }
		#column { display:flex; flex-direction:column; font:16px/22px Arial }
		#label { font:bold 12px/16px Arial; margin-bottom:4px }
		#title { font:16px/22px Arial }
	</style><div id="outer"><a id="inline"><div id="block"><div id="column"><span id="label">Label</span><span id="title">First line<br>Second line</span></div></div></a></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 1024, 768) or { panic('layout failed') }
	inline := chromium_inline_baseline_node(result.root, 'inline') or { panic('missing inline') }
	column := chromium_inline_baseline_node(result.root, 'column') or { panic('missing column') }
	inline_styled := inline.as_node_with_style() or { panic('inline has no style') }
	inline_state := result.state.try_get(inline_styled) or { panic('missing inline state') }
	// Brave's inline-block is 64px tall, starts 13px below the containing
	// line's top, and exports the label's 12px baseline through both wrappers.
	assert inline_state.content_height().to_double() == 64
	assert inline_state.offset.y().to_double() == 13
	assert layout_box_baseline_for_inline(result.state, inline).to_double() == 12
	// An ordinary consumer requesting the column's last set still gets the
	// second title line's baseline, rather than the label's first set.
	assert layout_box_baseline(result.state, column, .first).to_double() == 12
	assert layout_box_baseline(result.state, column, .last).to_double() == 58
}
