module css

import dom

fn test_explicit_parent_longhand_reuse_checks_normal_noninherited_values_and_mutations() {
	computer, _, element, original_parent := longhand_reuse_fixture()
	mut parent_style := unsafe { &ComputedProperties(original_parent) }
	for id, text in {PropertyID.vertical_align:'middle', .border_top_color:'red'} {
		parent_style.set_property(id, parse_css_value(ParsingParams{}, text, id) or { panic(text) }, .no, .no)
	}
	mut cascaded := CascadedProperties.new()
	for id in [PropertyID.vertical_align, .border_top_color] {
		cascaded.set_property(id, dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.inherit))),
			.yes, .author, none, unsafe { nil }, none)
	}
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut cascaded)
	key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascaded,
		parent_style, false) or { panic('explicit parent inputs must be eligible') }
	mut probe := computed_properties_with_initial_values()
	assert computer.restore_computed_longhands(key, cascaded, mut probe)
	actual := computer.compute_properties(dom.AbstractElement.new(element, none), mut cascaded)
	longhand_reuse_assert_oracle(actual, computer, element, mut cascaded)
	assert actual.is_property_inherited(.vertical_align)
	assert actual.is_property_important(.border_top_color)

	mut second_parent := &ComputedProperties{...parent_style, property_store_:parent_style.clone_raw_property_store(), computed_property_graph_token_:unsafe { nil }}
	second_parent.set_property(.vertical_align, parse_css_value(ParsingParams{}, 'top', .vertical_align) or { panic('top') }, .no, .no)
	changed := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascaded,
		second_parent, false) or { panic('changed explicit parent') }
	assert changed.hash != key.hash
	collision := ComputedLonghandReuseKey{...changed, hash:key.hash}
	assert !computer.restore_computed_longhands(collision, cascaded, mut probe)

	// The same retained parent box can mutate without replacing its page.
	value := parent_style.property(.border_top_color, .no) or { panic('border') }
	mut box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	box.value = StyleValue(ColorStyleValue.create(Color.rgba(0, 0, 255, 255)))
	assert !computer.restore_computed_longhands(key, cascaded, mut probe)
}

fn test_explicit_parent_longhand_reuse_rejects_resource_and_untyped_parent_inputs() {
	computer, _, element, original_parent := longhand_reuse_fixture()
	mut parent := unsafe { &ComputedProperties(original_parent) }
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	mut cascade := CascadedProperties.new()
	cascade.set_property(.background_image, dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.inherit))),
		.no, .author, none, unsafe { nil }, none)
	parent.set_property(.background_image, parse_css_value(ParsingParams{}, 'url(https://parent.test/image.svg)', .background_image) or { panic('image') }, .no, .no)
	assert computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascade, parent, false) == none
	parent.set_property(.background_image, &dom.StyleValue{css_text:'none'}, .no, .no)
	assert computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascade, parent, false) == none
}
