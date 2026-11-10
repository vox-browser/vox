module css

// https://drafts.csswg.org/css-text-4/#propdef-hyphenate-character
// auto | <string>
fn (mut parser Parser) parse_hyphenate_character_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}
	value := parser.parse_string_value(mut tokens) or { return none }
	return StyleValue(value)
}
