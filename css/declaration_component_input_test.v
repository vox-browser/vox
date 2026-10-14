module css

import dom

fn component_input_declaration(source string, document &dom.Document) &CSSStyleProperties {
	return parse_css_property_declaration_block_with_params(ParsingParams{
		document: document
		rule_context: [RuleContext.style]
	}, source)
}

fn test_declarations_preserve_comment_separated_token_boundaries() {
	declaration := component_input_declaration('width: 1/**/px; height: 2px; color: r/**/ed;', dom.Document.create(dom.url_about_blank()))
	assert declaration.get_property_value('width') == ''
	assert declaration.get_property_value('height') == '2px'
	assert declaration.get_property_value('color') == ''
}

fn test_declarations_reuse_nested_values_and_keep_custom_source_text() {
	declaration := component_input_declaration("--size: calc(2px + 3%); --word: 'hello'; width: var(--size, calc(4px + 5%)); padding: 1px 2px; display: inherit;", dom.Document.create(dom.url_about_blank()))
	assert declaration.get_property_value('--size') == 'calc(2px + 3%)'
	assert declaration.get_property_value('--word') == "'hello'"
	assert declaration.get_property_value('width').contains('var(--size')
	assert declaration.get_property_value('padding') == '1px 2px'
	assert declaration.get_property_value('display') == 'inherit'
}

fn test_custom_component_input_retains_the_supplied_original_text() {
	source := " /* keep */var(--word, 'hello') "
	values := parse_component_values_for_value_logic(source)
	value := parse_custom_property_components(values, source)
	assert value.css_text == source
}

fn test_declarations_keep_the_document_quirks_parsing_context() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_quirks_mode(.yes)
	declaration := component_input_declaration('width: 12; height: 13; opacity: .5;', document)
	assert declaration.get_property_value('width') == '12px'
	assert declaration.get_property_value('height') == '13px'
	assert declaration.get_property_value('opacity') == '0.5'
}
