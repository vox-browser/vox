module css

import dom

// A CSSOM-style read-only computed style for an element, backed by the minimal cascade + the
// computed-value resolvers. Mirrors `window.getComputedStyle(element)`: `get_property_value(name)`
// returns the property's computed value as a string.
pub struct ComputedStyleDeclaration {
	element      &dom.Element
	author_rules []&CSSRule
}

// The computed style of `element` (analogous to `getComputedStyle`).
pub fn get_computed_style(element &dom.Element, author_rules []&CSSRule) ComputedStyleDeclaration {
	return ComputedStyleDeclaration{
		element:      element
		author_rules: author_rules
	}
}

// The computed value of `property_name` as a string (analogous to `getPropertyValue`).
pub fn (declaration ComputedStyleDeclaration) get_property_value(property_name string) string {
	return computed_style_value(declaration.element, property_name, declaration.author_rules)
}

// Format a px value as a CSS length string, dropping the fractional part for whole numbers.
fn format_px(value f64) string {
	if value == f64(int(value)) {
		return '${int(value)}px'
	}
	return '${value}px'
}

// The computed value of `property_name` for `element` as a string. Resolved-value properties return
// their computed form — font-size and line-height as px, color-valued properties as `rgb(...)`, and
// lengths resolvable without layout (absolute/em/rem/calc) as px. Everything else returns the
// cascaded (specified) value.
//
// FIXME: layout-dependent used values (a percentage or `auto` width, etc.) fall back to the specified
// value here, since resolving them needs the layout tree.
pub fn computed_style_value(element &dom.Element, property_name string, author_rules []&CSSRule) string {
	id := property_id_from_string(property_name) or { return '' }
	if property_name == 'font-size' {
		return format_px(computed_font_size_px(element, author_rules))
	}
	if property_name == 'line-height' {
		return format_px(computed_line_height_px(element, author_rules))
	}
	// Color-valued properties serialize to rgb(); computed_color returns none for non-colors.
	if color := computed_color(element, id, author_rules) {
		return color.serialize()
	}
	// A length that resolves to px without a containing block (absolute/em/rem/calc).
	if px := computed_length_px(element, id, author_rules) {
		return format_px(px)
	}
	return cascaded_value_with_ua(element, id, author_rules)
}
