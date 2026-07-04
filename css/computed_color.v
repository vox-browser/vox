module css

import dom

fn color_property_id() PropertyID {
	return property_id_from_string('color') or { panic('no color property id') }
}

// Resolve `property_id`'s cascaded value to a concrete Color for `element`: named colors, hex,
// rgb()/rgba()/hsl()/etc., and `currentColor` (which resolves to the element's computed `color`).
// Returns none when the value isn't a color (e.g. a keyword like `none`, or a parse failure).
//
// FIXME: system colors depend on the color scheme (not wired here); calc()/color-mix inputs that
// need a layout node aren't resolved.
pub fn computed_color(element &dom.Element, property_id PropertyID, author_rules []&CSSRule) ?Color {
	specified := cascaded_value_with_ua(element, property_id, author_rules)
	value := parse_css_value_logic(property_id, specified) or { return none }
	mut context := ColorResolutionContext{}
	// `currentColor` resolves to the element's computed `color`. Guard against infinite recursion
	// when resolving the `color` property itself.
	if property_id != color_property_id() {
		context.current_color = computed_color(element, color_property_id(), author_rules)
	}
	return value.to_color(context)
}
