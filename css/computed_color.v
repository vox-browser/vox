module css

import dom

fn color_property_id() PropertyID {
	return property_id_from_string('color') or { panic('no color property id') }
}

// Resolve `property_id`'s cascaded value to a concrete Color for `element`: named colors, hex,
// rgb()/rgba()/hsl()/etc., and `currentColor` (which resolves to the element's computed `color`).
// Returns none when the value isn't a color (e.g. a keyword like `none`, or a parse failure).
//
// calc()/color-mix inputs that need a layout node aren't resolved.
pub fn computed_color(element &dom.Element, property_id PropertyID, author_rules []&CSSRule) ?Color {
	specified := cascaded_value_with_ua(element, property_id, author_rules)
	value := parse_css_value_logic(property_id, specified) or { return none }
	mut document := element.document()
	preferred_scheme := preferred_color_scheme_from_string(document.preferred_color_scheme())
	mut scheme := computed_interpolation_default_color_scheme(preferred_scheme,
		document.supported_color_schemes())
	color_scheme_text := cascaded_value_with_ua(element, .color_scheme, author_rules)
	color_scheme_value := parse_css_value_logic(.color_scheme, color_scheme_text) or {
		StyleValue(ColorSchemeStyleValue.normal())
	}
	if color_scheme_value is ColorSchemeStyleValue {
		if element_scheme := used_color_scheme_from_scheme_list(color_scheme_value.schemes(),
			preferred_scheme)
		{
			scheme = element_scheme
		}
	}
	mut context := ColorResolutionContext{
		color_scheme: scheme
		document: document
	}
	// `currentColor` resolves to the element's computed `color`. Guard against infinite recursion
	// when resolving the `color` property itself.
	if property_id != color_property_id() {
		context.current_color = computed_color(element, color_property_id(), author_rules)
	}
	return value.to_color(context)
}

// Parse a standalone CSS <color> string (e.g. a color token from a box-shadow or gradient) to a
// concrete Color: named colors, hex, rgb()/rgba()/hsl()/etc. Returns none when it isn't a color.
// `currentColor` isn't resolved here (there is no element context).
pub fn parse_color_string(text string) ?Color {
	value := parse_css_value_logic(color_property_id(), text) or { return none }
	return value.to_color(ColorResolutionContext{})
}
