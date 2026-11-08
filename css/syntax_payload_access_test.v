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
