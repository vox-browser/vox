module xpath

import dom

fn xpath_document() &dom.Document {
	document := dom.Document.create(dom.url_about_blank())
	mut root := document.create_element('root') or { panic(err) }
	mut first := document.create_element('item') or { panic(err) }
	first.set_attribute_for_bindings('id', 'a') or { panic(err) }
	mut first_node := first.as_node()
	first_node.append_child(document.create_text_node('10').as_node()) or { panic(err) }
	mut second := document.create_element('item') or { panic(err) }
	second.set_attribute_for_bindings('id', 'b') or { panic(err) }
	mut second_node := second.as_node()
	second_node.append_child(document.create_text_node('20').as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(first.as_node()) or { panic(err) }
	root_node.append_child(second.as_node()) or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic(err) }
	return document
}

fn test_evaluator_path_predicates_functions_and_scalars() {
	document := xpath_document()
	evaluator := XPathEvaluator.construct()
	mut all := evaluator.evaluate('//item', unsafe { &dom.Node(document) }, none,
		.ordered_node_snapshot, none)!
	assert all.snapshot_length() == 2
	assert (all.snapshot_item(1) or { panic('missing') }).text_content()? == '20'
	assert (all.iterate_next() or { panic('missing') }).text_content()? == '10'
	count := evaluator.evaluate('count(//item)', unsafe { &dom.Node(document) }, none, .any, none)!
	assert count.result_type == .number
	assert count.number_value == 2
	filtered := evaluator.evaluate("//item[@id='b']", unsafe { &dom.Node(document) }, none,
		.first_ordered_node, none)!
	assert (filtered.single_node_value() or { panic('missing') }).text_content()? == '20'
	attribute := evaluator.evaluate('string(//item[1]/@id)', unsafe { &dom.Node(document) }, none,
		.any, none)!
	assert attribute.string_value == 'a'
}

fn test_expression_reuse_types_and_syntax_errors() {
	document := xpath_document()
	evaluator := XPathEvaluator.construct()
	expression := evaluator.create_expression('/root/item[2]', none)!
	mut reusable := &XPathResult{}
	mut result := expression.evaluate(unsafe { &dom.Node(document) }, .ordered_node_iterator,
		reusable)!
	assert result == reusable
	assert (result.iterate_next() or { panic('missing') }).text_content()? == '20'
	assert result.iterate_next() == none
	invalid := evaluator.create_expression('//item[', none)!
	if _ := invalid.evaluate(unsafe { &dom.Node(document) }, .any, none) {
		assert false
	} else {
		assert err.str().contains('SyntaxError')
	}
}

fn test_mirrored_context_root_result_flavor_and_prefix_behavior() {
	document := xpath_document()
	evaluator := XPathEvaluator.construct()
	document_node := unsafe { &dom.Node(document) }
	root_matches := evaluator.evaluate('//root', document_node, none, .ordered_node_snapshot, none)!
	assert root_matches.snapshot_length() == 1
	root := document.document_element() or { panic('missing root') }
	first_item := root.as_node().first_child() or { panic('missing item') }
	context_root := evaluator.evaluate('/item', first_item, none, .first_ordered_node, none)!
	assert context_root.single_node_value()? == first_item
	requested_number := evaluator.evaluate('//item', document_node, none, .number, none)!
	assert requested_number.result_type == .unordered_node_iterator
	assert requested_number.snapshot_length() == 2
	prefixed := evaluator.evaluate('//x:item', document_node, fn (prefix string) ?string {
		_ = prefix
		return 'urn:test'
	}, .ordered_node_snapshot, none)!
	assert prefixed.snapshot_length() == 0
	quoted_parenthesis := evaluator.evaluate("'('", document_node, none, .any, none)!
	assert quoted_parenthesis.string_value == '('
	last := evaluator.evaluate('//item[last()]', document_node, none, .first_ordered_node, none)!
	assert last.single_node_value()?.text_content()? == '20'
}
