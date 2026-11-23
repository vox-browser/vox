module css

fn test_selector_identifiers_with_and_without_escapes() {
	for text, expected in {
		'card-title rest':   'card-title|10'
		'card\\:hover rest': 'card:hover|11'
		'\\31 23 rest':      '123|6'
		'β-name.rest':       'β-name|7'
		'trailing\\':        'trailing|8'
		'.':                 '|0'
	} {
		name, next := parse_identifier(text, 0)
		assert '${name}|${next}' == expected, text
	}
	name, next := parse_identifier('ab', 5)
	assert name == '' && next == 5
}
