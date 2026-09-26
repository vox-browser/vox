module css

fn color_property_id() PropertyID {
	return property_id_from_string('color') or { panic('no color property id') }
}

// Parse a standalone CSS <color> string (e.g. a color token from a box-shadow or gradient) to a
// concrete Color: named colors, hex, rgb()/rgba()/hsl()/etc. Returns none when it isn't a color.
// `currentColor` isn't resolved here (there is no element context).
pub fn parse_color_string(text string) ?Color {
	value := parse_css_value_logic(color_property_id(), text) or { return none }
	return value.to_color(ColorResolutionContext{})
}
