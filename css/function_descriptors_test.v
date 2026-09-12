module css

fn test_function_descriptors_parse_result_and_custom_names() {
	parsed := parse_css_descriptor_declaration_block(ParsingParams{}, .function_rule, 'result: var(--size); --size: 10px; --size: 20px; ignored: nope')
	descriptors := CSSFunctionDescriptors.create(parsed)

	assert descriptors.base.length() == 2
	assert descriptors.base.item(0) == 'result'
	assert descriptors.base.item(1) == '--size'
	assert descriptors.result() == 'var(--size)'
	assert descriptors.base.get_property_value('--size') == '20px'
	assert descriptors.base.serialized() == 'result: var(--size); --size: 20px;'
}

fn test_function_descriptors_support_cssom_mutation() {
	mut descriptors := CSSFunctionDescriptors.create([]Descriptor{})
	descriptors.set_result('calc(2 * var(--x))')!
	descriptors.base.set_property('--x', '4px', '')!

	assert descriptors.result() == 'calc(2 * var(--x))'
	assert descriptors.base.get_property_value('--x') == '4px'
	assert descriptors.base.get_property_value('--X') == ''
	assert descriptors.base.remove_property('--x')! == '4px'
	assert descriptors.base.get_property_value('--x') == ''
}

fn test_function_descriptors_reject_invalid_declaration_values() {
	parsed := parse_css_descriptor_declaration_block(ParsingParams{}, .function_rule, 'result: 10px !important; --bad: !; result: inherit')
	descriptors := CSSFunctionDescriptors.create(parsed)

	assert descriptors.base.length() == 1
	assert descriptors.result() == 'inherit'
}
