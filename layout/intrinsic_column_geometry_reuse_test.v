module layout

import html

fn column_reuse_test_node(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() {
		if found := column_reuse_test_node(child, id) { return found }
	}
	return none
}

fn column_reuse_test_used(result DocumentLayoutResult, id string) &UsedValues {
	node := column_reuse_test_node(result.root, id) or { panic('missing node') }
	styled := node.as_node_with_style() or { panic('missing style') }
	return result.used_values_for(styled) or { panic('missing used values') }
}

fn column_reuse_test_probe(markup string, height ?CSSPixels) (DocumentLayoutResult, FormattingContextResult, CSSPixels) {
	document := html.parse_document(markup)
	normal := run_document_layout(document, 800, 600) or { panic('layout failed') }
	node := column_reuse_test_node(normal.root, 'flex') or { panic('missing flex') }
	styled := node.as_node_with_style() or { panic('missing style') }
	expected_baseline := layout_box_baseline(normal.state, node, .first)
	mut source := normal.state
	mut probe := LayoutState.new_for_subtree(styled)
	populate_intrinsic_containing_block_chain(mut probe, mut source, node)
	populate_intrinsic_external_containing_blocks(mut probe, mut source, node, node)
	mut values := probe.get_mutable(styled)
	values.set_content_width(CSSPixels.new(120))
	values.set_has_definite_width(true)
	if definite := height {
		values.set_content_height(definite)
		values.set_has_definite_height(true)
	} else {
		values.set_indefinite_content_height()
	}
	available_height := if definite := height {
		AvailableSize.make_definite(definite)
	} else {
		AvailableSize.make_indefinite()
	}
	inside := run_flex_formatting_context_with_mode(mut probe, node, mut values, .intrinsic_sizing, AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(120)),
		available_height))
	return DocumentLayoutResult{
		root:     normal.root
		state:    probe
		document: document
	}, inside, expected_baseline
}

fn test_intrinsic_column_keeps_first_pass_text_baseline_before_discarding_lines() {
	result, inside, expected_baseline :=
		column_reuse_test_probe('<!doctype html><style>body{margin:0;font:16px/20px monospace}#flex{display:inline-flex;flex-direction:column;width:120px;min-height:80px;justify-content:center}.item{height:20px;flex:0 0 auto}</style><span id="flex"><span id="a" class="item">A</span><span id="b" class="item">B</span></span>', none)
	assert inside.automatic_content_height.to_double() == 40
	assert column_reuse_test_used(result, 'a').offset.y().to_double() == 20
	assert column_reuse_test_used(result, 'b').offset.y().to_double() == 40
	assert column_reuse_test_used(result, 'flex').derived_first_baseline()? == expected_baseline
	assert column_reuse_test_used(result, 'a').line_boxes.len == 0
	assert column_reuse_test_used(result, 'b').line_boxes.len == 0
}

fn test_intrinsic_column_still_resolves_percentage_descendants_after_height_promotion() {
	result, inside, _ :=
		column_reuse_test_probe('<!doctype html><style>body{margin:0}#flex{display:flex;flex-direction:column;width:120px}.leaf{height:20px}#percentage{height:50%}</style><div id="flex"><div id="item"><div id="percentage"></div><div class="leaf"></div></div></div>', none)
	assert inside.automatic_content_height.to_double() == 20
	assert column_reuse_test_used(result, 'item').content_height().to_double() == 20
	assert column_reuse_test_used(result, 'percentage').content_height().to_double() == 10
}

fn test_intrinsic_column_still_lays_out_items_after_changed_flex_targets() {
	result, inside, _ := column_reuse_test_probe('<!doctype html><style>body{margin:0}#flex{display:flex;flex-direction:column;width:120px;height:40px}.item{flex:1 1 auto;min-height:0}.leaf{height:50px}.percentage{height:50%}</style><div id="flex"><div id="a" class="item"><div id="pa" class="percentage"></div><div class="leaf"></div></div><div id="b" class="item"><div id="pb" class="percentage"></div><div class="leaf"></div></div></div>',
		CSSPixels.new(40))
	assert inside.automatic_content_height.to_double() == 40
	assert column_reuse_test_used(result, 'a').content_height().to_double() == 20
	assert column_reuse_test_used(result, 'b').content_height().to_double() == 20
	assert column_reuse_test_used(result, 'pa').content_height().to_double() == 10
	assert column_reuse_test_used(result, 'pb').content_height().to_double() == 10
}
