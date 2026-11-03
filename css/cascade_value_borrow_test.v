module css

import dom

fn borrowed_cascade_value(id PropertyID, text string) &dom.StyleValue {
	return parse_css_value(ParsingParams{}, text, id) or { panic(text) }
}

fn test_cascade_tag_reads_keep_typed_values_authoritative_over_serialized_text() {
	document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element('div')!
	abstract_element := dom.AbstractElement.new(element, none)
	for id, text in {PropertyID.width: '12px', .color: 'red', .opacity: '.4', .display: 'grid', .margin: '1px 2px'} {
		original := borrowed_cascade_value(id, text)
		value := &dom.StyleValue{css_text: 'revert-layer', css_value_handle: original.css_value_handle}
		assert !opaque_is_revert(id, value)
		assert !opaque_is_revert_layer(id, value)
		assert !opaque_is_unresolved(value)
		assert !opaque_is_pending_substitution(value)
		assert !opaque_is_guaranteed_invalid(value)
		assert voidptr(resolve_cascade_declaration_value(abstract_element, id, value)) == voidptr(value)
		gc_collect()
		assert !opaque_is_revert_layer(id, value)
	}
	for keyword in [Keyword.revert, .revert_layer] {
		original := dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(keyword)))
		value := &dom.StyleValue{css_text: 'red', css_value_handle: original.css_value_handle}
		assert opaque_is_revert(.color, value) == (keyword == .revert)
		assert opaque_is_revert_layer(.color, value) == (keyword == .revert_layer)
	}
}

fn test_cascade_tag_reads_observe_mutations_of_the_same_retained_box() {
	value := borrowed_cascade_value(.color, 'red')
	mut box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	for keyword in [Keyword.revert, .initial, .revert_layer, .unset] {
		box.value = StyleValue(KeywordStyleValue.create(keyword))
		gc_collect()
		assert opaque_is_revert(.color, value) == (keyword == .revert)
		assert opaque_is_revert_layer(.color, value) == (keyword == .revert_layer)
	}
}

fn test_untyped_cascade_bridge_values_keep_their_parser_fallback() {
	for text in ['revert', 'ReVeRt', ' \trevert\n'] {
		value := &dom.StyleValue{css_text: text}
		assert opaque_is_revert(.color, value)
		assert !opaque_is_revert_layer(.color, value)
	}
	for text in ['revert-layer', 'ReVeRt-LaYeR', '\nrevert-layer '] {
		value := &dom.StyleValue{css_text: text}
		assert opaque_is_revert_layer(.color, value)
		assert !opaque_is_revert(.color, value)
	}
	for text in ['red', 'var(--missing)', 'not a valid color'] {
		value := &dom.StyleValue{css_text: text}
		assert !opaque_is_revert(.color, value)
		assert !opaque_is_revert_layer(.color, value)
		// These three predicates have always required an actual typed box.
		assert !opaque_is_unresolved(value)
		assert !opaque_is_pending_substitution(value)
		assert !opaque_is_guaranteed_invalid(value)
	}
}

fn test_substitution_and_invalid_cascade_values_keep_their_distinct_paths() {
	document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element('div')!
	abstract_element := dom.AbstractElement.new(element, none)
	unresolved := parse_css_value_logic(.margin, 'var(--edges, 1px 2px)')?
	value := dom_style_value_from_value_logic(unresolved)
	pending := dom_style_value_from_value_logic(StyleValue(PendingSubstitutionStyleValue.create(unresolved)))
	invalid := dom_style_value_from_value_logic(StyleValue(GuaranteedInvalidStyleValue.create()))
	assert opaque_is_unresolved(value)
	assert !opaque_is_pending_substitution(value)
	assert opaque_is_pending_substitution(pending)
	assert !opaque_is_unresolved(pending)
	assert opaque_is_guaranteed_invalid(invalid)
	assert !opaque_is_guaranteed_invalid(value)
	assert voidptr(resolve_cascade_declaration_value(abstract_element, .margin_left, pending)) == voidptr(pending)
	assert resolve_cascade_declaration_value(abstract_element, .color, invalid).css_text == 'unset'
	mut styled := document.create_element('div')!
	styled.set_attribute_value('style', '--edge:9px;margin:var(--edge);color:var(--missing,red)')
	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(styled, none))
	assert computed.property(.margin_left, .no)?.css_text == '9px'
	assert computed.property(.margin_right, .no)?.css_text == '9px'
	color_value := computed.property(.color, .no)?
	typed_color := typed_style_value_logic_from_dom(color_value)?
	actual_color := typed_color.to_color(ColorResolutionContext{})?
	assert actual_color == Color{255, 0, 0, 255}
}

fn test_direct_cascade_keyword_checks_preserve_origin_and_layer_reverts() {
	document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element('div')!
	abstract_element := dom.AbstractElement.new(element, none)
	mut cascade := CascadedProperties.new()
	red := borrowed_cascade_value(.color, 'red')
	for index, row in [
		StyleProperty{property_id: .color, value: red},
		StyleProperty{property_id: .color, value: borrowed_cascade_value(.color, 'blue')},
		StyleProperty{property_id: .color, value: borrowed_cascade_value(.color, 'revert-layer')},
	] {
		layer := if index == 0 { 'base' } else { 'front' }
		apply_property_list_to_cascade(mut cascade, abstract_element, [row], .author, .no, layer,
			unsafe { nil }, none, none, [])
	}
	layer_color := cascade.property(.color)?
	assert voidptr(layer_color) == voidptr(red)
	mut origins := CascadedProperties.new()
	green := borrowed_cascade_value(.color, 'green')
	for origin in [CascadeOrigin.user, .author] {
		apply_property_list_to_cascade(mut origins, abstract_element,
			[StyleProperty{property_id: .color, value: if origin == .user { green } else { borrowed_cascade_value(.color, 'blue') }}],
			origin, .no, none, unsafe { nil }, none, none, [])
	}
	apply_property_list_to_cascade(mut origins, abstract_element,
		[StyleProperty{property_id: .color, value: borrowed_cascade_value(.color, 'revert')}],
		.author, .no, none, unsafe { nil }, none, none, [])
	origin_color := origins.property(.color)?
	assert voidptr(origin_color) == voidptr(green)
}
