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

	s := StyleComputer.new(doc)
	mut cascaded := CascadedProperties.new()
	s.cascade_declarations(mut cascaded, abstract_element, []MatchingRule{}, CascadeOrigin.author,
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

// compute_properties turns cascaded values into computed values and runs the tail adjustments; here the
// effective-overflow rule applies: overflow-y: scroll forces overflow-x: visible to compute to auto.
fn test_compute_properties_resolves_effective_overflow() {
	doc := dom.Document.create(dom.url_about_blank())
	mut el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	el.set_attribute_value('style', 'overflow-x: visible; overflow-y: scroll')
	abstract_element := dom.AbstractElement.new(el, none)

	s := StyleComputer.new(doc)
	mut cascaded := CascadedProperties.new()
	s.cascade_declarations(mut cascaded, abstract_element, []MatchingRule{}, CascadeOrigin.author,
		Important.no, none, none, []PropertyID{})

	mut computed := s.compute_properties(abstract_element, mut cascaded)
	assert computed.overflow_y() == .scroll
	// overflow-x: visible computes to auto because overflow-y is neither visible nor clip.
	assert computed.overflow_x() == .auto_
}

// compute_logical_alias_mapping_context cascades only writing-mode + direction and maps them to the
// flow-relative context used for resolving logical property aliases.
fn test_compute_logical_alias_mapping_context() {
	doc := dom.Document.create(dom.url_about_blank())
	mut el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	el.set_attribute_value('style', 'writing-mode: vertical-rl; direction: rtl')
	abstract_element := dom.AbstractElement.new(el, none)

	s := StyleComputer.new(doc)
	// One (empty) author layer so the author-origin cascade runs and reads the element's inline style
	// (the real build_matching_rule_set always yields at least the un-named author layer).
	matching_rule_set := MatchingRuleSet{
		author_rules: [LayerMatchingRules{}]
	}
	context := s.compute_logical_alias_mapping_context(abstract_element, ComputeStyleMode.normal,
		matching_rule_set)
	assert context.writing_mode == .vertical_rl
	assert context.direction == .rtl
}
