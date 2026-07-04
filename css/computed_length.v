module css

import dom

// Resolve `property_id`'s cascaded value to absolute px for `element`, when it is a length. This
// feeds real pixel numbers to layout: absolute lengths convert directly; em/ex/ch resolve against
// the element's computed font-size; rem against the root element's font-size.
//
// Returns none for values that can't be resolved to px here: percentages (they need a
// containing-block basis that only layout has), keywords like 'auto', calc(), and viewport units.
//
// NOTE: correct for non-inherited length properties (width/height/margin/padding/border-width/insets
// — the common layout inputs). FIXME: for the few INHERITED length properties (letter-spacing,
// line-height, ...) a relative unit inherited from an ancestor is resolved against this element's
// font-size rather than the ancestor's.
pub fn computed_length_px(element &dom.Element, property_id PropertyID, author_rules []&CSSRule) ?f64 {
	specified := cascaded_value_with_ua(element, property_id, author_rules)
	value := parse_css_value_logic(property_id, specified) or { return none }
	if !value.is_length() {
		return none
	}
	length := value.as_length().length()
	if length.is_absolute() {
		return length.absolute_length_to_px().to_double()
	}
	raw := length.raw_value()
	unit := length.unit_name()
	if unit == 'em' {
		return raw * computed_font_size_px(element, author_rules)
	}
	if unit == 'rem' {
		return raw * root_font_size_px(element, author_rules)
	}
	if unit == 'ex' || unit == 'ch' {
		return raw * computed_font_size_px(element, author_rules) * 0.5 // approximation
	}
	return none // FIXME: viewport units need the viewport size
}

// The percentage value of `property_id`'s cascaded value (e.g. 50.0 for `50%`), or none when the
// value isn't a percentage. Layout resolves this against the relevant containing-block basis (a
// percentage width against the containing block's width, etc.).
pub fn computed_percentage(element &dom.Element, property_id PropertyID, author_rules []&CSSRule) ?f64 {
	specified := cascaded_value_with_ua(element, property_id, author_rules)
	value := parse_css_value_logic(property_id, specified) or { return none }
	if !value.is_percentage() {
		return none
	}
	return value.as_percentage().percentage().value()
}
