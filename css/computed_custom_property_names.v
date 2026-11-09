module css

// CSSOM includes non-invalid custom properties after the ordinary longhands,
// including registered initial values and inherited custom declarations.
fn (properties &CSSStyleProperties) computed_custom_property_names() []string {
	owner := properties.owner_node or { return []string{} }
	_ = up_to_date_computed_properties_for_element(owner.element())
	mut candidates := map[string]bool{}
	if data := owner.custom_property_data() {
		for name, _ in data.all_values() { candidates[name] = true }
	}
	document := owner.document()
	for name, _ in document.registered_property_set { candidates[name] = true }
	for name, _ in document.cached_registered_properties_from_css_property_rules { candidates[name] = true }
	mut names := []string{}
	for name, _ in candidates {
		if _ := properties.custom_property(name) { names << name }
	}
	names.sort()
	return names
}

pub fn (properties &CSSStyleProperties) property_names() []string {
	properties.ensure_declarations_parsed()
	mut names := []string{}
	if properties.is_computed() {
		if properties.owner_node == none { return names }
		for i in 0 .. number_of_longhand_properties {
			if id := property_id_from_longhand_index(i) { names << string_from_property_id(id) }
		}
		names << properties.computed_custom_property_names()
		return names
	}
	for i in 0 .. css_style_properties_length(properties) { names << properties.item(uint(i)) }
	return names
}
