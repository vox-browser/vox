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

// https://drafts.csswg.org/css-text-4/#propdef-hyphenate-limit-chars
// [ auto | <integer> ]{1,3}
// A missing second value is auto and a missing third value equals the second, so
// keep the shortest equivalent list: `5 2 2` is `5 2`, `5 auto auto` is `5`.
fn (mut parser Parser) parse_hyphenate_limit_chars_value(mut tokens ComponentValueStream) ?StyleValue {
	mut values := []StyleValue{}
	for values.len < 3 {
		mut transaction := tokens.clone()
		if value := parse_property_keyword_value(mut transaction, ['auto']) {
			values << value
			tokens = transaction
			continue
		}
		transaction = tokens.clone()
		value := parser.parse_integer_value(mut transaction) or { break }
		values << value
		tokens = transaction
	}
	if values.len == 0 {
		return none
	}
	if values.len == 3 && values[2].serialize(.normal) == values[1].serialize(.normal) {
		values.delete(2)
	}
	if values.len == 2 && values[1].to_keyword() == .auto {
		values.delete(1)
	}
	if values.len == 1 {
		return values[0]
	}
	return StyleValue(StyleValueList.create(values, .space, .no))
}

// https://drafts.csswg.org/css-text-4/#propdef-hyphenate-limit-lines
// no-limit | <integer [0,∞]>
fn (mut parser Parser) parse_hyphenate_limit_lines_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['no-limit']) {
		tokens = transaction
		return value
	}
	transaction = tokens.clone()
	value := parser.parse_integer_value(mut transaction) or { return none }
	if value is IntegerStyleValue && value.integer() < 0 {
		return none
	}
	tokens = transaction
	return value
}
