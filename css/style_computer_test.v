module css

import dom

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

// cascade_declarations over an element's inline style: direct properties are set and shorthands are
// expanded into the CascadedProperties (empty matching rules -> only the inline author style applies).
fn test_cascade_declarations_inline_style() {
	doc := dom.Document.create(dom.url_about_blank())
	mut el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	el.set_attribute_value('style', 'color: red; padding: 10px')
	abstract_element := dom.AbstractElement.new(el, none)

	mut cascaded := CascadedProperties.new()
	cascade_declarations(mut cascaded, abstract_element, []MatchingRule{}, CascadeOrigin.author,
		Important.no, none, none, []PropertyID{})

	// The direct `color` declaration is cascaded.
	color_id := property_id_from_string('color') or { panic('no color id') }
	if _ := cascaded.property(color_id) {
	} else {
		panic('color was not cascaded')
	}
	// The `padding` shorthand is expanded to its longhands (padding-top = 10px).
	padding_top_id := property_id_from_string('padding-top') or { panic('no padding-top id') }
	padding_top := cascaded.property(padding_top_id) or { panic('padding-top not cascaded (shorthand not expanded)') }
	assert padding_top.css_text == '10px'
}
