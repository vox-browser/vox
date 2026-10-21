module css

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn test_initial_style_template_keeps_property_storage_flags_and_maps_independent() {
	mut first := computed_properties_with_initial_values()
	second := computed_properties_with_initial_values()
	initial_width := second.property(.width, .no) or { panic('missing initial width') }
	width := parse_css_value(ParsingParams{}, '43px', .width) or { panic('invalid width') }
	first.set_property(.width, width, .yes, .yes)
	first.set_animated_property(.height, width, .yes, .yes)
	first.set_animated_custom_property('--x', width)
	first.add_inheritance_dependent_specified_value(.width, width)
	mut first_values := unsafe { &MutableComputedValues(first) }
	first_values.set_font_variation_settings({
		'wght': f64(650)
	})
	assert (second.property(.width, .no) or { panic('missing width') }).css_text == initial_width.css_text
	assert !second.is_property_important(.width)
	assert !second.is_property_inherited(.width)
	assert !second.has_animated_properties()
	assert !second.has_animated_custom_properties()
	assert second.inheritance_dependent_specified_values().len == 0
	assert second.font_variation_storage_ == unsafe { nil }
	third := computed_properties_with_initial_values()
	assert !third.has_animated_properties()
	assert third.font_variation_storage_ == unsafe { nil }
}

fn test_resolving_one_initial_style_does_not_change_another_or_the_template() {
	mut first := computed_properties_with_initial_values()
	second := computed_properties_with_initial_values()
	width := parse_css_value(ParsingParams{}, '43px', .width) or { panic('invalid width') }
	first.set_property(.width, width, .no, .no)
	_ = resolve_computed_values(first)
	assert first.computed_values_resolved_
	assert !second.computed_values_resolved_
	third := computed_properties_with_initial_values()
	assert !third.computed_values_resolved_
	_ = resolve_computed_values(second)
	assert first.computed_layout_cache().computed_values_width_ != second.computed_layout_cache().computed_values_width_
	assert second.root_font_size_px_ == 16
	assert second.root_line_height_px_ == 19.2
	assert second.cached_computed_font_list_ == none
	assert second.computed_layout_cache().rare_data().computed_values_rotate_ == none
	assert second.computed_content() == none
}

fn test_initial_style_template_retains_nested_defaults_across_collection() {
	first := computed_properties_with_initial_values()
	for _ in 0 .. 3 {
		$if gcboehm ? { C.GC_gcollect() }
		next := computed_properties_with_initial_values()
		assert next.computed_layout_cache().computed_values_width_ == first.computed_layout_cache().computed_values_width_
		assert next.computed_layout_cache().computed_values_margin_ == first.computed_layout_cache().computed_values_margin_
		assert next.computed_layout_cache().computed_values_stroke_width_ == first.computed_layout_cache().computed_values_stroke_width_
		assert next.computed_list_style_type().counter_style == none
		assert next.computed_layout_cache().computed_values_fill_ == none
		assert next.computed_layout_cache().rare_data().computed_values_mask_ == none
		assert next.computed_layout_cache().rare_data().computed_values_clip_path_ == none
	}
}
