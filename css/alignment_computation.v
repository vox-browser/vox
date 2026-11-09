module css

import dom

fn alignment_computed_value(value StyleValue) StyleValue {
	if value is KeywordStyleValue {
		return match value.keyword() {
			.flex_start { StyleValue(KeywordStyleValue.create(.flow_start)) }
			.flex_end { StyleValue(KeywordStyleValue.create(.flow_end)) }
			else { value }
		}
	}
	if value is StyleValueList {
		mut entries := []StyleValue{}
		for entry in value.values() { entries << alignment_computed_value(entry) }
		return StyleValue(StyleValueList.create(entries, .space, .yes))
	}
	return value
}

// CSS Align: the flow-relative aliases compute canonically. A bare legacy
// justify-items uses the parent's legacy tuple, otherwise normal. Resolve it
// after cached longhands so the value continues to follow its actual parent.
fn compute_alignment_values(mut properties ComputedProperties, element dom.AbstractElement) {
	for property in [PropertyID.align_content, .justify_content, .align_items,
		.justify_items, .align_self, .justify_self] {
		raw := properties.property(property, .no) or { continue }
		value := typed_style_value_logic_from_dom(raw) or { continue }
		mut computed := alignment_computed_value(value)
		if property == .justify_items && value.to_keyword() == .legacy {
			computed = StyleValue(KeywordStyleValue.create(.normal))
			properties.add_inheritance_dependent_specified_value(property, raw)
			if parent := parent_computed_properties(element) {
				if inherited := parent.property(.justify_items, .yes) {
					if tuple := typed_style_value_logic_from_dom(inherited) {
						if tuple is StyleValueList && tuple.values().len == 2
							&& tuple.values()[0].to_keyword() == .legacy { computed = tuple }
					}
				}
			}
		}
		if !computed.equals(value) {
			properties.set_property_without_modifying_flags(property, dom_style_value_from_value_logic(computed))
		}
	}
}
