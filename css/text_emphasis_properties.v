module css

// https://drafts.csswg.org/css-text-decor-4/#text-emphasis-position-property
// auto | [ over | under ] && [ right | left ]?
// right is the default side, so it is omitted from the canonical value
// (`right under` serializes as `under`), as WPT and other engines expect.
fn (mut parser Parser) parse_text_emphasis_position_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}
	transaction = tokens.clone()
	mut over_under := StyleValue(KeywordStyleValue.create(.invalid))
	mut has_over_under := false
	mut left := false
	mut has_left_right := false
	for _ in 0 .. 2 {
		mut attempt := transaction.clone()
		if value := parse_property_keyword_value(mut attempt, ['over', 'under']) {
			if has_over_under {
				return none
			}
			over_under = value
			has_over_under = true
			transaction = attempt
			continue
		}
		attempt = transaction.clone()
		if value := parse_property_keyword_value(mut attempt, ['left', 'right']) {
			if has_left_right {
				return none
			}
			left = value.to_keyword() == .left
			has_left_right = true
			transaction = attempt
			continue
		}
		break
	}
	if !has_over_under {
		return none
	}
	tokens = transaction
	if left {
		return StyleValue(StyleValueList.create([over_under, StyleValue(KeywordStyleValue.create(.left))],
			.space, .no))
	}
	return over_under
}
