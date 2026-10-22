module css

import dom

// Expansion calls this synchronously. Keep the caller's state on its stack,
// rather than retaining an expanded-longhand array for every declaration.
struct CSSOMDeclarationBuilder {
mut:
	declaration &CSSStyleProperties = unsafe { nil }
	important   Important
	base_url    ?string
}

fn (mut declaration CSSStyleProperties) append_parsed_declaration(property StyleProperty) {
	mut builder := CSSOMDeclarationBuilder{
		declaration: declaration
		important:   property.important
		base_url:    property.value.base_url
	}
	StyleComputer.for_each_property_expanding_shorthands_with_context(property.property_id,
		property.value, voidptr(&builder), append_cssom_longhand)
}

fn append_cssom_longhand(context voidptr, property_id PropertyID, value &dom.StyleValue) {
	mut builder := unsafe { &CSSOMDeclarationBuilder(context) }
	mut declaration := builder.declaration
	mut retained_value := unsafe { &dom.StyleValue(value) }
	if retained_value.base_url == none { retained_value.base_url = builder.base_url }
	name := string_from_property_id(property_id)
	for index, existing in declaration.properties {
		if existing.name != name { continue }
		if existing.important && builder.important == .no { return }
		declaration.properties.delete(index)
		break
	}
	declaration.properties << CSSStyleProperty{
		name:        name
		value:       dom_style_value_to_css_text(value)
		important:   builder.important == .yes
		style_value: unsafe { value }
	}
}
