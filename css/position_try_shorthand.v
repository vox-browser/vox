module css

fn (mut parser Parser) parse_position_try_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	mut order := StyleValue(KeywordStyleValue.create(.normal))
	mut order_tokens := transaction.clone()
	if parsed := parser.parse_position_try_order_value(mut order_tokens) {
		order = parsed
		transaction = order_tokens
		transaction.consume_whitespace()
	}
	fallbacks := parser.parse_position_try_fallbacks_value(mut transaction) or { return none }
	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.position_try,[PropertyID.position_try_order,.position_try_fallbacks],[order,fallbacks]))
}
