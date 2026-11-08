module css

// Accessors borrow the payload only for their call. Constructors and extracted
// tokens still copy their value, so editing a local cannot mutate parser input.
fn test_syntax_payload_access_preserves_constructor_and_extraction_value_semantics() {
	mut token := Token.create_ident('before', 'before')
	component := ComponentValue.from_token(token)
	token.value = 'after'
	assert component.is_ident('BEFORE')
	assert !component.is_ident('after')
	mut extracted := component.token()
	extracted.value = 'extracted'
	assert component.token().ident() == 'before'
	assert component.original_source_text() == 'before'

	mut block := SimpleBlock{token: Token.create(.open_curly, '{'),
		value: [component], end_token: Token.create(.close_curly, '}')}
	wrapped := ComponentValue.from_block(block)
	block.token = Token.create(.open_square, '[')
	assert wrapped.is_curly_block()
	assert !wrapped.is_function()
	assert !wrapped.is(.ident)
	assert wrapped.block().value[0].is_ident('before')
	assert wrapped.original_source_text() == '{before}'

	mut function := Function{name: 'fn', name_token: Token.create_function('fn', 'fn('),
		value: [wrapped], end_token: Token.create(.close_paren, ')')}
	call := ComponentValue.from_function(function)
	function.name = 'changed'
	assert call.is_function_named('FN')
	assert !call.is_function_named('changed')
	assert !call.is_curly_block()
	assert call.function().value[0].is_curly_block()
	assert call.original_source_text() == 'fn({before})'
}

fn test_syntax_payload_predicates_accept_temporaries_and_mixed_component_arrays() {
	values := ParserTokenStream.from_source('a > :is([title="β😀"]) { --x: calc(1px + 2%); }', 'utf-8').values
	for value in values {
		if value.is_token() {
			assert !value.is_block() && !value.is_function()
			assert value.is(value.token().token_type())
		} else if value.is_block() {
			assert !value.is_token() && !value.is_function()
		} else {
			assert value.is_function()
		}
	}
	assert ComponentValue.from_token(Token.create_delim(`>`, '>')).is_delim(`>`)
	assert !ComponentValue.from_token(Token.create_ident('>', '>')).is_delim(`>`)
	assert !ComponentValue.from_token(Token.create_delim(`a`, 'a')).is_ident('a')
}

fn test_reference_payload_dispatch_preserves_serialization_and_owned_nested_values() {
	source := ':is(.a, [\\61=b]):nth-child(+2n+1)'
	values := ParserTokenStream.from_source(source, 'utf-8').values
	for owned in [own_stylesheet_components(values), own_value_components(values)] {
		assert parser_component_values_original_text(owned) == source
		assert parser_selector_prelude_to_string(owned) == ':is(.a, [a=b]):nth-child(+2n+1)'
		for value in owned {
			assert !value.contains_guaranteed_invalid_value()
			assert value.to_string() != ''
			assert value.to_debug_string() != ''
		}
	}
	raw := ComponentValue.new('raw text')
	assert raw.original_source_text() == 'raw text'
	assert raw.to_string() == 'raw text'
	assert raw.to_debug_string() == 'Raw: raw text'
	assert !raw.contains_guaranteed_invalid_value()
	invalid := ComponentValue.from_guaranteed_invalid(GuaranteedInvalidValue{})
	block := ComponentValue.from_block(SimpleBlock{value: [invalid]})
	function := ComponentValue.from_function(Function{name: 'f', value: [block]})
	assert invalid.contains_guaranteed_invalid_value()
	assert block.contains_guaranteed_invalid_value()
	assert function.contains_guaranteed_invalid_value()
	for value in [invalid, block, function] {
		assert own_value_component(value).contains_guaranteed_invalid_value()
		assert own_stylesheet_component(value).contains_guaranteed_invalid_value()
	}
}
