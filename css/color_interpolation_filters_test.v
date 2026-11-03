module css

import dom

fn color_interpolation_filters_serialization(text string) ?string {
	value := parse_css_value_logic(.color_interpolation_filters, text) or { return none }
	return value.serialize(.normal)
}

fn test_color_interpolation_filters_metadata_and_parsing() {
	assert number_of_longhand_properties == 364
	assert last_longhand_property_id() == .webkit_font_smoothing
	assert property_id_from_string('color-interpolation-filters')? == .color_interpolation_filters
	assert property_id_from_string('COLOR-INTERPOLATION-FILTERS')? == .color_interpolation_filters
	assert string_from_property_id(.color_interpolation_filters) == 'color-interpolation-filters'
	assert property_initial_value_string(.color_interpolation_filters) == 'linearrgb'
	assert is_inherited_property(.color_interpolation_filters)
	assert animation_type_from_longhand_property(.color_interpolation_filters) == .discrete
	assert is_animatable_property(.color_interpolation_filters)
	assert !property_affects_layout(.color_interpolation_filters)
	assert generated_shorthands_for_longhand(.color_interpolation_filters) == [
		PropertyID.all,
	]
	assert PropertyID.color_interpolation_filters in generated_longhands_for_shorthand(.all)
	assert PropertyID.color_interpolation_filters in generated_expanded_longhands_for_shorthand(.all)

	for valid in ['auto', 'sRGB', 'linearRGB', 'LiNeArRgB'] {
		assert color_interpolation_filters_serialization(valid)? == valid.to_lower()
	}
	for invalid in ['none', 'linearRGB sRGB', 'auto sRGB linearRGB'] {
		assert color_interpolation_filters_serialization(invalid) == none, invalid
	}
}

fn test_color_interpolation_filters_computed_value_and_presentation_attribute() {
	document := dom.Document.create(dom.url_about_blank())
	mut primitive := document.create_element_ns('http://www.w3.org/2000/svg', 'feColorMatrix') or {
		panic(err)
	}
	computer := StyleComputer.new(document)

	initial := computer.compute_style(dom.AbstractElement.new(primitive, none))
	assert initial.color_interpolation_filters() == .srgb_linear
	assert resolve_computed_values_for_document(initial, document).color_interpolation_filters() == .srgb_linear

	primitive.set_attribute_value('color-interpolation-filters', 'sRGB')
	presentation := computer.compute_style(dom.AbstractElement.new(primitive, none))
	assert presentation.color_interpolation_filters() == .srgb
	assert (presentation.property(.color_interpolation_filters, .no) or {
		panic('missing presentation property')
	}).css_text == 'srgb'

	primitive.set_attribute_value('style', 'color-interpolation-filters: auto')
	overridden := computer.compute_style(dom.AbstractElement.new(primitive, none))
	assert overridden.color_interpolation_filters() == .auto_
}
