module css

import dom

fn retained_style_copy(source &ComputedProperties) &ComputedProperties {
	return &ComputedProperties{
		...source
		property_store_:                source.clone_raw_property_store()
		computed_property_graph_token_: &ComputedPropertyGraphMutationToken{}
	}
}

fn test_retained_layout_style_requires_every_raw_value_and_flag_to_match() {
	mut document, _, target, _ := computed_query_fixture()
	defer { document.finalize() }
	previous := up_to_date_computed_properties_for_element(target)
	_ = resolve_computed_values_for_document(previous, document)
	identical := retained_style_copy(previous)
	assert previous.has_identical_retained_layout_inputs(identical, document)
	for id in [PropertyID.color, .font_size, .font_weight, .font_width, .letter_spacing, .word_spacing,
		.fill] {
		mut scalar_copy := retained_style_copy(previous)
		value := previous.property(id, .no)?
		typed := typed_style_value_logic_from_dom(value)?
		scalar_copy.set_property_without_modifying_flags(id, dom_style_value_from_value_logic(typed))
		assert scalar_copy.reuse_unchanged_font_cache(previous, css_style_computer_for(document).font_computer())
		assert previous.has_identical_retained_layout_inputs(scalar_copy, document), '${id}'
	}
	for id in [PropertyID.width, .color, .display, .margin_left, .font_size, .content] {
		mut changed := retained_style_copy(previous)
		changed.set_property_without_modifying_flags(id, &dom.StyleValue{ css_text: 'different' })
		assert !previous.has_identical_retained_layout_inputs(changed, document)
	}
	mut flags := retained_style_copy(previous)
	flags.property_important_[0] ^= 1
	assert !previous.has_identical_retained_layout_inputs(flags, document)
	flags = retained_style_copy(previous)
	flags.property_inherited_[0] ^= 1
	assert !previous.has_identical_retained_layout_inputs(flags, document)
}

fn test_retained_layout_style_rejects_changed_context_fonts_animations_and_unknown_provenance() {
	mut document, _, target, _ := computed_query_fixture()
	defer { document.finalize() }
	previous := up_to_date_computed_properties_for_element(target)
	_ = resolve_computed_values_for_document(previous, document)
	for kind in 0 .. 9 {
		mut changed := retained_style_copy(previous)
		match kind {
			0 { changed.viewport_rect_.width = CSSPixels.new(123) }
			1 { changed.root_font_size_px_ += 1 }
			2 { changed.root_line_height_px_ += 1 }
			3 { changed.subject_element_ = none }
			4 { changed.cached_computed_font_list_ = none }
			5 { changed.cached_computed_font_list_generation_++ }
			6 { changed.line_height_ = CSSPixels.new(20) }
			7 { changed.set_animated_property(.opacity, &dom.StyleValue{ css_text: '0.5' }, .no, .no) }
			else { changed.property_store_ = unsafe { nil } }
		}
		assert !previous.has_identical_retained_layout_inputs(changed, document), '${kind}'
	}
	mut unresolved := retained_style_copy(previous)
	unresolved.computed_values_resolved_ = false
	assert !unresolved.has_identical_retained_layout_inputs(previous, document)
	mut mutated := unsafe { &ComputedProperties(previous) }
	mutated.set_property_without_modifying_flags(.width, &dom.StyleValue{ css_text: '77px' })
	assert !mutated.has_identical_retained_layout_inputs(retained_style_copy(mutated), document)
}

fn test_retained_layout_scalar_comparison_keeps_units_types_and_resource_identity() {
	px := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(10))))
	em := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.new(10, .em))))
	copy_px := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(10))))
	assert retained_layout_values_match(px, copy_px)
	assert !retained_layout_values_match(px, em)
	assert !retained_layout_values_match(px, dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(10))))
	// Equal text cannot validate an untyped compatibility value or a new
	// resource graph, even when its serialization matches the old one.
	assert !retained_layout_values_match(&dom.StyleValue{ css_text: '10px' }, &dom.StyleValue{ css_text: '10px' })
	image := parse_css_value(ParsingParams{}, 'url("https://example.com/image.png")', .background_image)?
	copy_image := parse_css_value(ParsingParams{}, 'url("https://example.com/image.png")', .background_image)?
	assert retained_layout_values_match(image, image)
	assert !retained_layout_values_match(image, copy_image)
}
