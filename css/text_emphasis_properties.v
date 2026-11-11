module css

import dom

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

const text_emphasis_shapes = ['dot', 'circle', 'double-circle', 'triangle', 'sesame']

// https://drafts.csswg.org/css-text-decor-4/#text-emphasis-style-property
// none | [ [ filled | open ] || [ dot | circle | double-circle | triangle | sesame ] ] | <string>
// The fill keyword precedes the shape in the canonical specified value.
fn (mut parser Parser) parse_text_emphasis_style_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['none']) {
		tokens = transaction
		return value
	}
	transaction = tokens.clone()
	if value := parser.parse_string_value(mut transaction) {
		tokens = transaction
		return StyleValue(value)
	}
	transaction = tokens.clone()
	mut fill := ?StyleValue(none)
	mut shape := ?StyleValue(none)
	for _ in 0 .. 2 {
		mut attempt := transaction.clone()
		if value := parse_property_keyword_value(mut attempt, ['filled', 'open']) {
			if fill != none {
				return none
			}
			fill = value
			transaction = attempt
			continue
		}
		attempt = transaction.clone()
		if value := parse_property_keyword_value(mut attempt, text_emphasis_shapes) {
			if shape != none {
				return none
			}
			shape = value
			transaction = attempt
			continue
		}
		break
	}
	mut values := []StyleValue{}
	if value := fill {
		values << value
	}
	if value := shape {
		values << value
	}
	if values.len == 0 {
		return none
	}
	tokens = transaction
	if values.len == 1 {
		return values[0]
	}
	return StyleValue(StyleValueList.create(values, .space, .no))
}

// The computed value is none, a string, or a shape with its fill: a missing shape
// becomes circle in horizontal writing modes and sesame in vertical ones, and the
// default filled fill is omitted (`filled` computes to `circle`, `open` to
// `open circle`).
fn compute_text_emphasis_style(value &dom.StyleValue, writing_mode &dom.StyleValue) &dom.StyleValue {
	typed := typed_style_value_logic_from_dom(value) or { return value }
	mut keywords := []Keyword{}
	if typed is KeywordStyleValue {
		keywords << typed.to_keyword()
	} else if typed is StyleValueList {
		for entry in typed.values() {
			keywords << entry.to_keyword()
		}
	} else {
		return value
	}
	if keywords == [Keyword.none_] {
		return value
	}
	open := Keyword.open in keywords
	mut shape := Keyword.invalid
	for keyword in keywords {
		if keyword !in [Keyword.filled, .open] {
			shape = keyword
		}
	}
	if shape == .invalid {
		horizontal := (computed_interpolation_style_value_keyword(writing_mode) or {
			Keyword.horizontal_tb
		}) == .horizontal_tb
		shape = if horizontal { Keyword.circle } else { Keyword.sesame }
	}
	shape_value := StyleValue(KeywordStyleValue.create(shape))
	computed := if open {
		StyleValue(StyleValueList.create([StyleValue(KeywordStyleValue.create(.open)), shape_value],
			.space, .no))
	} else {
		shape_value
	}
	if computed.serialize(.normal) == typed.serialize(.normal) {
		return value
	}
	return dom_style_value_from_value_logic(computed)
}
