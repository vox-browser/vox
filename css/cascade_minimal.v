module css

import dom

// A minimal, genuinely-working slice of the CSS cascade, built on the property metadata generated
// in property_metadata.v plus the (working) inline-style declaration parser and property database.
//
// The full StyleComputer.compute_style is still a stub in this port (author/UA/user stylesheet rule
// matching needs stylesheet rule parsing, which is also stubbed). What DOES work end to end is the
// inline (specified) origin + inheritance + initial-value defaulting, which this exposes.

// https://drafts.csswg.org/css-cascade/#inherited-property — does this longhand inherit by default?
pub fn is_inherited_property(property_id PropertyID) bool {
	return string_from_property_id(property_id) in inherited_properties
}

// The property's initial value, as a source string (from Properties.json), or '' if none.
pub fn property_initial_value_string(property_id PropertyID) string {
	return property_initial_values[string_from_property_id(property_id)] or { '' }
}

// The element's declared value for `property_name` from its inline style attribute, if present.
fn inline_declared_value(element &dom.Element, property_name string) ?string {
	style_text := element.get_attribute('style') or { return none }
	if style_text.len == 0 {
		return none
	}
	block := parse_css_property_declaration_block_with_parser(style_text)
	value := block.get_property_value(property_name)
	if value.len == 0 {
		return none
	}
	return value
}

// Resolve the cascaded/specified value of `property_id` for `element`:
//   1. an inline declaration on the element, otherwise
//   2. (if the property inherits) the nearest ancestor's inline declaration for it, otherwise
//   3. the property's initial value.
// FIXME: author/UA/user stylesheet rules are not part of this cascade yet (rule parsing is stubbed).
pub fn cascaded_value_for(element &dom.Element, property_id PropertyID) string {
	name := string_from_property_id(property_id)
	if value := inline_declared_value(element, name) {
		return value
	}
	if is_inherited_property(property_id) {
		mut ancestor := element.as_node().parent_element()
		for {
			current := ancestor or { break }
			if value := inline_declared_value(current, name) {
				return value
			}
			ancestor = current.as_node().parent_element()
		}
	}
	return property_initial_value_string(property_id)
}
