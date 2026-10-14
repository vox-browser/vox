module css

fn test_ascii_case_matching_compares_bytes_without_unicode_folding() {
	assert equals_ignoring_ascii_case('', '')
	assert equals_ignoring_ascii_case('URL', 'url')
	assert equals_ignoring_ascii_case('MaRgIn-InLiNe', 'margin-inline')
	assert equals_ignoring_ascii_case('cafÉ', 'CAFÉ')
	assert !equals_ignoring_ascii_case('É', 'é')
	assert !equals_ignoring_ascii_case('K', 'K')
	assert !equals_ignoring_ascii_case('url', 'urls')
	assert !equals_ignoring_ascii_case('@', '`')
	assert !equals_ignoring_ascii_case('[', '{')
}

fn test_component_keyword_matching_keeps_non_ascii_identifiers_distinct() {
	assert ComponentValue.from_token(Token.create_ident('AuTo', 'AuTo')).is_ident('auto')
	assert !ComponentValue.from_token(Token.create_ident('É', 'É')).is_ident('é')
	assert ComponentValue.from_function(Function{ name: 'CALC' }).is_function_named('calc')
	assert !ComponentValue.from_function(Function{ name: 'CAFÉ' }).is_function_named('café')
}
