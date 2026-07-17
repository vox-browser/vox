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
		// A calc() that resolves without a percentage basis (e.g. calc(50px + 2em)) is absolute here;
		// a calc() needing a percentage is left to layout (which has the containing basis).
		if value.is_calculated() {
			context := calc_resolution_context(element, none, author_rules)
			if length := value.as_calculated().resolve_length(context) {
				return length.to_px(context.length_resolution_context).to_double()
			}
		}
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

// Resolve a box-model length/percentage property (margin/padding/border-width/width/height/inset...) from
// THIS computed style to px, for the real layout engine (which holds a css.ComputedProperties, not a DOM
// element). `percentage_basis_px` is the reference for `%` (the containing block's inline size for
// horizontal box-model properties, block size for vertical). Returns none for `auto`, other keywords, and
// viewport/rem units (the layout algorithm handles auto; FIXME: rem/viewport need root/viewport metrics).
pub fn (c &ComputedProperties) length_percentage_to_px(property_id PropertyID, percentage_basis_px f64) ?f64 {
	value := c.property(property_id, .yes) or { return none }
	typed := parse_css_value_logic(property_id, value.css_text) or { return none }
	if typed.is_percentage() {
		return percentage_basis_px * typed.as_percentage().percentage().value() / 100.0
	}
	if !typed.is_length() {
		return none
	}
	length := typed.as_length().length()
	if length.is_absolute() {
		return length.absolute_length_to_px().to_double()
	}
	unit := length.unit_name()
	raw := length.raw_value()
	font_px := c.resolved_font_size_px()
	if unit == 'em' {
		return raw * font_px
	}
	if unit == 'ex' || unit == 'ch' {
		return raw * font_px * 0.5 // approximation
	}
	return none
}

// This computed style's font-size in px (already absolute in a computed style). Falls back to 16px.
pub fn (c &ComputedProperties) resolved_font_size_px() f64 {
	value := c.property(.font_size, .yes) or { return 16.0 }
	typed := parse_css_value_logic(.font_size, value.css_text) or { return 16.0 }
	if typed.is_length() {
		length := typed.as_length().length()
		if length.is_absolute() {
			return length.absolute_length_to_px().to_double()
		}
	}
	return 16.0
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

// A calc() resolution context using `element`'s computed font-size (for em/ex/ch), the root font-size
// (for rem), and an optional percentage basis in px (the containing measure for `%` inside the calc).
fn calc_resolution_context(element &dom.Element, percentage_basis_px ?f64, author_rules []&CSSRule) CalculationResolutionContext {
	mut font_metrics := LengthFontMetrics.default()
	font_metrics.font_size = CSSPixels.nearest_value_for(computed_font_size_px(element, author_rules))
	mut root_font_metrics := LengthFontMetrics.default()
	root_font_metrics.font_size = CSSPixels.nearest_value_for(root_font_size_px(element, author_rules))
	mut length_context := LengthResolutionContext.default()
	length_context.font_metrics = font_metrics
	length_context.root_font_metrics = root_font_metrics
	mut context := CalculationResolutionContext{
		length_resolution_context: length_context
	}
	if basis := percentage_basis_px {
		context.percentage_basis = CalculationPercentageBasis(Length.make_px(basis))
	}
	return context
}

// Resolve `property_id`'s cascaded value to px when it is a calc() expression, resolving any `%`
// inside it against `percentage_basis_px` (e.g. the containing width for a width calc). Returns none
// when the value isn't a calc() or doesn't resolve to a length.
pub fn computed_calc_px(element &dom.Element, property_id PropertyID, percentage_basis_px f64, author_rules []&CSSRule) ?f64 {
	specified := cascaded_value_with_ua(element, property_id, author_rules)
	value := parse_css_value_logic(property_id, specified) or { return none }
	if !value.is_calculated() {
		return none
	}
	context := calc_resolution_context(element, percentage_basis_px, author_rules)
	length := value.as_calculated().resolve_length(context) or { return none }
	return length.to_px(context.length_resolution_context).to_double()
}
