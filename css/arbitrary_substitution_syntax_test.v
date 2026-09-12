module css

import dom

fn test_property_parser_validates_substitution_function_argument_grammar() {
	valid := parse_css_value_logic(.width, 'calc(var(--fallback) + 1px)') or {
		panic('valid substitution function was rejected')
	}
	assert valid is UnresolvedStyleValue

	for invalid in ['var(,)', 'attr()', 'inherit(!!, 1px)', 'if()'] {
		assert parse_css_value_logic(.width, invalid) == none, invalid
	}
}

fn test_universal_syntax_validates_substitution_function_argument_grammar() {
	universal := SyntaxNode.create_universal()
	assert parse_with_a_syntax(parse_component_values_for_value_logic('var(--fallback)'), universal).type_() == .unresolved
	assert parse_with_a_syntax(parse_component_values_for_value_logic('var(,)'), universal).type_() == .guaranteed_invalid
}

fn test_function_parameter_default_rejects_invalid_substitution_syntax() {
	assert parse_css_rule_with_params(ParsingParams{}, '@function --valid(--x: var(--fallback)) { }') != none
	assert parse_css_rule_with_params(ParsingParams{}, '@function --invalid(--x: var(, 1px)) { }') == none
}

fn test_typed_om_rejects_invalid_unparsed_substitution_syntax() {
	value := CSSUnparsedValue.create([CSSUnparsedSegment('var(,)')])
	value.create_an_internal_representation(PropertyNameAndID.from_id(.width), .yes) or {
		assert err.msg().contains('TypeError')
		return
	}
	assert false, 'CSSUnparsedValue must reject invalid substitution syntax'
}

fn test_var_substitution_tokenizes_typed_registered_custom_properties() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic(err)
	}
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(target.as_node()) or { panic(err) }
	add_document_author_style_sheet(document, '@property --amount { syntax: "<percentage>"; inherits: false; initial-value: 25%; }
		div { width: var(--amount); }')
	css_style_computer_for(document)
	document.needs_full_style_update = true
	document.update_style()
	abstract_target := dom.AbstractElement.new(target, none)
	mut guarded_contexts := GuardedSubstitutionContexts{}
	tokens := computed_custom_property_tokens_for_substitution(abstract_target, '--amount', mut guarded_contexts) or {
		panic('registered custom property did not compute')
	}
	assert tokens.len == 1
	assert tokens[0].is(.percentage)
	assert tokens[0].token().percentage() == 25
	assert computed_value_for(target, .width) or { '' } == '25%'
}
