module css

import dom

fn custom_function_test_element(document &dom.Document, name string, id string) &dom.Element {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', name) or {
		panic(err)
	}
	if id.len > 0 {
		element.set_attribute_value('id', id)
	}
	return element
}

fn custom_function_test_tree(css_text string) (&dom.Document, &dom.Element, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := custom_function_test_element(document, 'html', '')
	mut target := custom_function_test_element(document, 'div', 'target')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(target.as_node()) or { panic(err) }
	add_document_author_style_sheet(document, css_text)
	css_style_computer_for(document)
	document.needs_full_style_update = true
	document.update_style()
	return document, root, target
}

fn custom_function_computed_custom_property(element &dom.Element, name string) string {
	value := StyleComputer.compute_value_of_custom_property(dom.AbstractElement.new(element, none), name)
	typed := typed_style_value_logic_from_dom(value) or { return value.css_text.trim_space() }
	if typed is GuaranteedInvalidStyleValue {
		return ''
	}
	return typed.serialize(.normal).trim_space()
}

fn test_custom_function_registry_is_available_through_a_custom_property_dependency() {
	_, _, target := custom_function_test_tree('@function --bar() {
		result: calc(1 + 1);
	}
	#target {
		--test: --bar();
		z-index: var(--test);
	}')
	computed := CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(target, none))
	assert computed.get_property_value('z-index') == '2'
}

fn test_var_fallback_extends_the_whole_substitution_cycle() {
	_, _, target := custom_function_test_tree('#target {
		--outer: var(--inner, blue);
		--inner: var(--loop, var(--outer));
		--loop: var(--inner);
		color: var(--outer, red);
	}')
	assert computed_value_for(target, .color) or { '' } == 'rgb(255, 0, 0)'
}

fn test_custom_function_property_context_includes_function_identity() {
	_, _, target := custom_function_test_tree('@function --outer() {
		--value: --inner();
		result: --inherit-value();
	}
	@function --inherit-value() {
		--value: inherit(--value);
		result: var(--value);
	}
	@function --inner() {
		--value: var(--pass);
		result: var(--value);
	}
	#target {
		--pass: PASS;
		--actual: --outer();
	}')
	assert custom_function_computed_custom_property(target, '--actual') == 'PASS'
}

fn test_custom_function_argument_evaluation_precedes_arity_failures() {
	_, _, target := custom_function_test_tree('@function --fallback(--value: fallback) {
		result: var(--value);
	}
	@function --missing(--required) {
		result: --fallback(--missing());
	}
	@function --excess() {
		result: --fallback(--excess(extra));
	}
	@function --takes-none() {
		result: unused;
	}
	@function --substitute-excess() {
		result: --fallback(--takes-none(--substitute-excess()));
	}
	@function --inherit-result() returns <color> {
		result: inherit;
	}
	@function --default-result(--value: --inherit-result()) {
		result: var(--value, green);
	}
	@function --outer-result() {
		result: --default-result();
	}
	#target {
		--missing-argument: --missing(present);
		--excess-arguments: --excess();
		--excess-argument-substitution: --substitute-excess();
		--noncyclic-missing: --fallback(--missing());
		--noncyclic-excess: --fallback(--takes-none(extra));
		--argument-default-result-keyword: --outer-result();
	}')
	assert custom_function_computed_custom_property(target, '--missing-argument') == ''
	assert custom_function_computed_custom_property(target, '--excess-arguments') == ''
	assert custom_function_computed_custom_property(target, '--excess-argument-substitution') == ''
	assert custom_function_computed_custom_property(target, '--noncyclic-missing') == 'fallback'
	assert custom_function_computed_custom_property(target, '--noncyclic-excess') == 'fallback'
	assert custom_function_computed_custom_property(target, '--argument-default-result-keyword') == 'green'
}

fn test_custom_function_result_css_wide_keywords_follow_return_syntax() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := custom_function_test_element(document, 'html', '')
	mut parent := custom_function_test_element(document, 'div', 'parent')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(parent.as_node()) or { panic(err) }
	mut children := map[string]&dom.Element{}
	for id in ['universal', 'universal-substitution', 'typed', 'typed-substitution', 'nested',
		'nested-substitution'] {
		mut child := custom_function_test_element(document, 'div', id)
		mut parent_node := parent.as_node()
		parent_node.append_child(child.as_node()) or { panic(err) }
		children[id] = child
	}
	add_document_author_style_sheet(document, '@function --universal-inherit() {
		result: inherit;
	}
	@function --universal-substituted-inherit() {
		result: var(--missing, inherit);
	}
	@function --typed-inherit() returns <number> {
		result: inherit;
	}
	@function --typed-substituted-inherit() returns <number> {
		result: var(--missing, inherit);
	}
	@function --nested-inherit() {
		--value: --typed-inherit();
		result: var(--value, 0.7);
	}
	@function --nested-substituted-inherit() {
		--value: --typed-substituted-inherit();
		result: var(--value, 0.7);
	}
	#parent { opacity: 0.4; }
	#universal { opacity: --universal-inherit(); }
	#universal-substitution { opacity: --universal-substituted-inherit(); }
	#typed { opacity: --typed-inherit(); }
	#typed-substitution { opacity: --typed-substituted-inherit(); }
	#nested { opacity: --nested-inherit(); }
	#nested-substitution { opacity: --nested-substituted-inherit(); }')
	css_style_computer_for(document)
	document.needs_full_style_update = true
	document.update_style()

	assert computed_value_for(children['universal'] or { panic('missing child') }, .opacity) or { '' } == '0.4'
	assert computed_value_for(children['universal-substitution'] or { panic('missing child') }, .opacity) or { '' } == '0.4'
	assert computed_value_for(children['typed'] or { panic('missing child') }, .opacity) or { '' } == '1'
	assert computed_value_for(children['typed-substitution'] or { panic('missing child') }, .opacity) or { '' } == '1'
	assert computed_value_for(children['nested'] or { panic('missing child') }, .opacity) or { '' } == '0.7'
	assert computed_value_for(children['nested-substitution'] or { panic('missing child') }, .opacity) or { '' } == '0.7'
}
