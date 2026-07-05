module css

// declaration_style_properties re-types a serialized CSSStyleProperties declaration into the typed
// StyleProperty list the cascade iterates over, mirroring Ladybird's CSSStyleProperties::properties().
fn test_declaration_style_properties() {
	mut declaration := CSSStyleProperties.create()
	declaration.properties << CSSStyleProperty{
		name:      'color'
		value:     'red'
		important: true
	}
	declaration.properties << CSSStyleProperty{
		name:      'width'
		value:     '10px'
		important: false
	}
	declaration.properties << CSSStyleProperty{
		name:      'not-a-real-property'
		value:     'x'
		important: false
	}

	props := declaration_style_properties(declaration)
	// The unknown property is skipped.
	assert props.len == 2

	color_id := property_id_from_string('color') or { panic('no color id') }
	width_id := property_id_from_string('width') or { panic('no width id') }
	assert props[0].property_id == color_id
	assert props[0].important == Important.yes
	assert props[1].property_id == width_id
	assert props[1].important == Important.no
	// Values are opaque dom.StyleValues carrying the serialized text.
	assert props[1].value.css_text == '10px'
}
