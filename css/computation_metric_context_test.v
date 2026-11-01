module css

import dom

fn metric_context_compare(computer &StyleComputer, properties &ComputedProperties,
	element &dom.Element, id PropertyID, value &dom.StyleValue) {
	abstract_element := dom.AbstractElement.new(element, none)
	mut full := computer.get_computation_context_for_property(id, properties, abstract_element)
	full.reset_viewport_metric_dependency_tracking()
	mut selected := computer.computation_context_for_value(id, value, properties, abstract_element)
	selected.reset_viewport_metric_dependency_tracking()
	source := ComputedPropertyValueSource{properties: properties}
	expected := compute_value_of_property_from_source(id, value, source, full, 1.0)
	actual := compute_value_of_property_from_source(id, value, source, selected, 1.0)
	left := typed_style_value_logic_from_dom(expected) or { panic('expected typed value') }
	right := typed_style_value_logic_from_dom(actual) or { panic('actual typed value') }
	assert left.equals(right), string_from_property_id(id)
	assert actual.css_text == expected.css_text, string_from_property_id(id)
	assert selected.did_resolve_viewport_relative_length == full.did_resolve_viewport_relative_length
	assert selected.did_resolve_font_relative_length == full.did_resolve_font_relative_length
	assert selected.did_resolve_font_face_relative_length == full.did_resolve_font_face_relative_length
	computer.clear_computation_context_caches()
}

fn test_metric_free_context_matches_full_computation_for_absolute_values_and_property_conversions() {
	computer, _, parent, element := on_demand_context_tree('font-size:20px;line-height:30px',
		'font-size:15px;line-height:24px;background-image:none,none;writing-mode:vertical-rl;direction:rtl')
	mut document := parent.document()
	document.set_font_rendering_policy(.chromium)
	properties := computer.compute_style(dom.AbstractElement.new(element, none))
	for id in [PropertyID.width, .height, .min_width, .max_width, .margin_left,
		.padding_top, .border_top_width, .outline_width, .outline_offset, .letter_spacing,
		.word_spacing, .tab_size] {
		value := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(1.75))))
		assert !computed_value_needs_metric_context(id, value)
		metric_context_compare(computer, properties, element, id, value)
	}
	for id in [PropertyID.width, .height, .font_width] {
		value := dom_style_value_from_value_logic(StyleValue(PercentageStyleValue.create(Percentage.new(63))))
		assert !computed_value_needs_metric_context(id, value)
		metric_context_compare(computer, properties, element, id, value)
	}
	for id in [PropertyID.opacity, .flex_grow, .font_weight] {
		value := dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(0.75)))
		assert !computed_value_needs_metric_context(id, value)
		metric_context_compare(computer, properties, element, id, value)
	}
	for id in [PropertyID.order, .z_index] {
		value := dom_style_value_from_value_logic(StyleValue(IntegerStyleValue.create(-3)))
		assert !computed_value_needs_metric_context(id, value)
		metric_context_compare(computer, properties, element, id, value)
	}
	for id in [PropertyID.color, .background_color, .border_top_color] {
		value := dom_style_value_from_value_logic(StyleValue(ColorStyleValue.create(Color.rgba(7, 8, 9, 128))))
		assert !computed_value_needs_metric_context(id, value)
		metric_context_compare(computer, properties, element, id, value)
	}
	for keyword in [Keyword.auto, .none_, .normal] {
		value := dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(keyword)))
		assert !computed_value_needs_metric_context(.width, value)
		metric_context_compare(computer, properties, element, .width, value)
	}
}

fn test_metric_context_keeps_font_relative_viewport_and_compound_values_on_the_full_path() {
	computer, _, _, element := on_demand_context_tree('font-size:20px;line-height:30px',
		'font-size:15px;line-height:24px')
	properties := computer.compute_style(dom.AbstractElement.new(element, none))
	for id, text in {PropertyID.width:'2em', .height:'3vw', .margin_left:'calc(2em + 3px)',
		.font_size:'150%', .line_height:'2', .font_weight:'bolder', .math_depth:'add(2)',
		.background_color:'CanvasText', .border_top_left_radius:'3px 4px'} {
		value := parse_css_value(ParsingParams{}, text, id) or { panic(text) }
		assert computed_value_needs_metric_context(id, value), text
		metric_context_compare(computer, properties, element, id, value)
	}
	for keyword in [Keyword.initial, .inherit, .unset, .revert, .revert_layer] {
		value := dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(keyword)))
		assert computed_value_needs_metric_context(.width, value)
	}
}

fn test_metric_free_values_preserve_full_style_dependencies_and_recompute_after_relative_mutations() {
	computer, _, parent, mut element := on_demand_context_tree('font-size:10vw;line-height:2em',
		'width:17.25px;height:63%;margin-left:2px;opacity:.75;z-index:7')
	for _ in 0 .. 3 {
		computed := computer.compute_style(dom.AbstractElement.new(element, none))
		assert computed.length_percentage_to_px(.width, 0)? == 17.25
		assert computed.length_percentage_to_px(.height, 200)? == 126
		assert computed.font_metrics_depend_on_viewport_metrics()
		assert computed.is_property_inherited(.font_size)
		assert !computed.is_property_inherited(.width)
		assert computer.computation_context_cache_is_empty()
		gc_collect()
	}
	element.set_attribute_value('style', 'font-size:12px;line-height:1;width:2em;height:3vw')
	changed := computer.compute_style(dom.AbstractElement.new(element, none))
	assert changed.length_percentage_to_px(.width, 0)? == 24
	assert changed.length_percentage_to_px(.height, 0)? == 15
	assert changed.depends_on_viewport_metrics()
	assert !changed.font_metrics_depend_on_viewport_metrics()
	assert computer.computation_context_cache_is_empty()
	_ = parent
}
