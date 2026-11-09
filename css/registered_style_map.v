module css

// Specified custom properties retain their token stream. Computed registered
// properties instead reify their grammar's individual typed iterations.
fn (mut property_map StylePropertyMapReadOnly) registered_custom_values(property PropertyNameAndID) ?[]CSSStyleValue {
	if !property.is_custom_property() { return none }
	element := property_map.element or { return none }
	_ = up_to_date_computed_properties_for_element(element.element())
	registration := element.document().get_registered_custom_property(property.name()) or { return none }
	syntax := style_query_registration_syntax(registration) or { return none }
	if syntax.type() == .universal { return none }
	value := property_map.get_style_value(property) or { return []CSSStyleValue{} }
	mut typed := typed_style_value_logic_from_dom(value) or {
		StyleValue(UnresolvedStyleValue.create(parse_component_values_for_value_logic(value.css_text)))
	}
	if typed is UnresolvedStyleValue { typed = parse_with_a_syntax(typed.tokenize(), syntax) }
	if typed is GuaranteedInvalidStyleValue { return []CSSStyleValue{} }
	mut result := []CSSStyleValue{}
	if typed is StyleValueList && typed.reify(property.name()).transform_value_ == none {
		for item in typed.values() { result << reify_registered_iteration(item, property.name()) }
	} else {
		result << reify_registered_iteration(typed, property.name())
	}
	return result
}

fn reify_registered_iteration(value StyleValue, name string) CSSStyleValue {
	if value is CustomIdentStyleValue { return value.reify(name) }
	if value is CalculatedStyleValue {
		if numeric := CSSNumericValue.parse(value.serialize(.normal)) {
			return CSSStyleValue.from_numeric(numeric)
		}
	}
	return value.reify(name)
}
