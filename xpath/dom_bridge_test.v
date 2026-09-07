module xpath

import dom

fn bridge_xpath_document() &dom.Document {
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

fn test_document_xpath_bridge_preserves_expression_and_result_identity() {
	install_dom_xpath_bridge()
	document := bridge_xpath_document()
	document_node := unsafe { &dom.Node(document) }

	expression := document.create_expression("//item[@id='b']", none)!
	assert expression.expression == "//item[@id='b']"
	mut reusable := &dom.XPathResult{}
	mut result := expression.evaluate(document_node, u16(dom.XPathResultType.ordered_node_iterator),
		reusable)!
	assert result == reusable
	assert result.result_type() == .ordered_node_iterator
	assert result.snapshot_length() == 1
	assert result.iterate_next()?.text_content()? == '20'
	assert result.iterate_next() == none

	count := document.evaluate('count(//item)', document_node, none, u16(dom.XPathResultType.any),
		none)!
	assert count.result_type() == .number
	assert count.number_value() == 2
}

fn test_document_xpath_bridge_rejects_invalid_expression_and_result_type() {
	install_dom_xpath_bridge()
	document := bridge_xpath_document()
	document_node := unsafe { &dom.Node(document) }
	invalid := document.create_expression('//item[', none)!
	if _ := invalid.evaluate(document_node, u16(dom.XPathResultType.any), none) {
		assert false
	} else {
		assert err.msg().contains('SyntaxError')
	}
	if _ := document.evaluate('//item', document_node, none, 99, none) {
		assert false
	} else {
		assert err.msg().contains('Invalid XPathResult type')
	}
}
