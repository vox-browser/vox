module css

import dom

fn font_radius_cascade(text string) &CascadedProperties {
	mut cascade := CascadedProperties.new()
	for id, value_text in {PropertyID.font_size:'18px', .line_height:'1.25', .width:'63px', .border_top_left_radius:text} {
		value := parse_css_value(ParsingParams{}, value_text, id) or { panic('radius fixture') }
		cascade.set_property(id, value, .no, .author, none, unsafe { nil }, none)
	}
	return cascade
}

fn test_font_radius_longhands_match_all_values_and_dependencies_for_both_font_policies() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for text in ['1.5rem','0.75rem 20%','1.25rem 0.5rem','12px 0.5rem'] {
			mut computer, parent, element, parent_style := longhand_reuse_fixture()
			mut document := parent.document()
			defer { document.finalize() }
			document.set_font_rendering_policy(policy)
			computer.root_element_font_metrics = LengthFontMetrics{font_size:CSSPixels.nearest_value_for(16.125),font_size_unrounded:16.125}
			computer.root_element_font_metrics_depend_on_viewport_metrics = true
			mut cascade := font_radius_cascade(text)
			computer.begin_computed_property_page_batch()
			_ = computer.compute_properties(dom.AbstractElement.new(element,none),mut cascade)
			_ = computer.compute_properties(dom.AbstractElement.new(element,none),mut cascade)
			key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element,none),cascade,parent_style,false)
			if retain_font_radius_longhands { assert key == none }
			else {
				actual_key := key or { panic('radius key') }
				assert actual_key.font_size_units
				mut actual := computed_properties_with_initial_values()
				assert computer.restore_computed_longhands(actual_key,cascade,mut actual)
				font_size_unit_assert_matches_uncached(actual,computer,element,mut cascade)
			}
			computer.end_computed_property_page_batch()
		}
	}
}

fn test_font_radius_longhands_reject_live_payload_and_fractional_environment_changes() {
	if retain_font_radius_longhands { return }
	for change in ['horizontal','vertical','elliptical','root','parent'] {
		mut computer, parent, element, parent_style := longhand_reuse_fixture()
		defer { parent.document().finalize() }
		computer.root_element_font_metrics = LengthFontMetrics{font_size:CSSPixels.new(16),font_size_unrounded:16.0001}
		mut cascade := font_radius_cascade('1.25rem 0.5rem')
		computer.begin_computed_property_page_batch()
		_ = computer.compute_properties(dom.AbstractElement.new(element,none),mut cascade)
		_ = computer.compute_properties(dom.AbstractElement.new(element,none),mut cascade)
		key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element,none),cascade,parent_style,false) or { panic('key') }
		mut probe := computed_properties_with_initial_values()
		assert computer.restore_computed_longhands(key,cascade,mut probe)
		property := cascade.style_property(.border_top_left_radius) or { panic('radius') }
		mut box := unsafe { &TypedStyleValueBox(property.value.css_value_handle) }
		if mut box.value is BorderRadiusStyleValue {
			if change=='horizontal' { box.value.horizontal_radius[0] = StyleValue(LengthStyleValue.create(Length.new(1.75,.rem))) }
			if change=='vertical' { box.value.vertical_radius[0] = StyleValue(LengthStyleValue.create(Length.new(0.75,.rem))) }
			if change=='elliptical' { box.value.is_elliptical_ = !box.value.is_elliptical_ }
		}
		if change=='root' { computer.root_element_font_metrics.font_size_unrounded=16.0002 }
		if change=='parent' {
			mut owner := unsafe { &ComputedProperties(parent_style) }
			owner.set_property(.font_size,dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(23.25)))),.no,.no)
		}
		if changed := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element,none),cascade,parent_style,false) {
			assert !computer.restore_computed_longhands(changed,cascade,mut probe),change
		}
		actual := computer.compute_properties(dom.AbstractElement.new(element,none),mut cascade)
		font_size_unit_assert_matches_uncached(actual,computer,element,mut cascade)
		computer.end_computed_property_page_batch()
	}
}

fn test_font_radius_longhands_keep_owned_outputs_after_retirement_and_parent_changes() {
	if retain_font_radius_longhands { return }
	computer, parent, element, parent_style := longhand_reuse_fixture()
	defer { parent.document().finalize() }
	mut original := font_radius_cascade('1rem 1.5rem')
	mut current := font_radius_cascade('1rem 1.5rem')
	computer.begin_computed_property_page_batch()
	_ = computer.compute_properties(dom.AbstractElement.new(element,none),mut original)
	_ = computer.compute_properties(dom.AbstractElement.new(element,none),mut original)
	key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element,none),current,parent_style,false) or { panic('key') }
	mut actual := computed_properties_with_initial_values()
	assert computer.restore_computed_longhands(key,current,mut actual)
	// The ordinary root-relative radius path has no inherited-source record.
	// The hit must preserve that state and keep an owned computed px value.
	assert actual.inheritance_specified_storage_ == unsafe { nil }
	assert (actual.property(.border_top_left_radius,.no) or { panic('computed radius') }).css_text.contains('px')
	computer.end_computed_property_page_batch()
	gc_collect()
	old := original.style_property(.border_top_left_radius) or { panic('old') }
	mut box := unsafe { &TypedStyleValueBox(old.value.css_value_handle) }
	if mut box.value is BorderRadiusStyleValue { box.value.horizontal_radius[0]=StyleValue(LengthStyleValue.create(Length.new(100,.rem))) }
	mut abstract := dom.AbstractElement.new(element,none)
	abstract.set_computed_properties(computed_properties_to_dom(actual))
	mut owner := unsafe { &ComputedProperties(parent_style) }
	owner.set_property(.font_size,dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(23.25)))),.no,.no)
	_ = computer.recompute_inherited_style_with_invalidation(mut abstract)
	font_size_unit_assert_matches_uncached(actual,computer,element,mut current)
}

fn test_font_radius_longhands_keep_metric_calculated_and_list_wrapped_radii_excluded() {
	for text in ['1em','1rem 1em','1ch','1lh','1rlh','1ex','1cap','1cqw','calc(1rem + 1px)'] {
		value := parse_css_value(ParsingParams{},text,.border_top_left_radius) or { panic('excluded radius') }
		assert !computed_longhand_reuse_property_is_simple(.border_top_left_radius,value),text
	}
	value := parse_css_value(ParsingParams{},'1.5rem',.border_top_left_radius) or { panic('radius') }
	typed := typed_style_value_logic_from_dom(value) or { panic('typed') }
	wrapped := StyleValue(StyleValueList.create([typed],.space,.no))
	assert !computed_longhand_reuse_typed_value_is_simple(&wrapped)
}

fn test_font_radius_hits_do_not_retain_an_old_percentage_leaf_after_batch_retirement() {
	if retain_font_radius_longhands { return }
	computer, parent, element, parent_style := longhand_reuse_fixture()
	defer { parent.document().finalize() }
	mut original := font_radius_cascade('1rem 20%')
	mut current := font_radius_cascade('1rem 20%')
	computer.begin_computed_property_page_batch()
	_ = computer.compute_properties(dom.AbstractElement.new(element,none),mut original)
	_ = computer.compute_properties(dom.AbstractElement.new(element,none),mut original)
	key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element,none),current,parent_style,false) or { panic('key') }
	mut actual := computed_properties_with_initial_values()
	assert computer.restore_computed_longhands(key,current,mut actual)
	computer.end_computed_property_page_batch()
	gc_collect()
	old := original.style_property(.border_top_left_radius) or { panic('old') }
	mut box := unsafe { &TypedStyleValueBox(old.value.css_value_handle) }
	if mut box.value is BorderRadiusStyleValue {
		mut component := unsafe { &box.value.vertical_radius[0] }
		if mut component is PercentageStyleValue { component.percentage_ = Percentage.new(99) }
		assert (box.value.vertical_radius[0] as PercentageStyleValue).percentage_.value_ == 99
	}
	font_size_unit_assert_matches_uncached(actual,computer,element,mut current)
}
