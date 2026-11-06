module css

import dom

fn font_size_unit_cascade() &CascadedProperties {
	mut cascade := CascadedProperties.new()
	for id, text in {PropertyID.font_size:'1.125em', .line_height:'1.3em',
		.margin_top:'-0.25em', .width:'3.5em', .padding_left:'0.75rem',
		.border_top_width:'0.03125rem', .letter_spacing:'0.004375rem'} {
		value := parse_css_value(ParsingParams{}, text, id) or { panic('value') }
		cascade.set_property(id, value, .no, .author, none, unsafe { nil }, none)
	}
	return cascade
}

fn font_size_unit_assert_matches_uncached(actual &ComputedProperties, computer &StyleComputer,
	element &dom.Element, mut cascade CascadedProperties) {
	mut oracle := StyleComputer.new(computer.document_)
	oracle.root_element_font_metrics = computer.root_element_font_metrics
	oracle.root_element_font_metrics_depend_on_viewport_metrics = computer.root_element_font_metrics_depend_on_viewport_metrics
	oracle.viewport_rect_ = computer.viewport_rect_
	// Outside a shared batch there is no reuse key. Compare every longhand and
	// its flags, not only the em/rem outputs selected by this fixture.
	expected := oracle.compute_properties(dom.AbstractElement.new(element, none), mut cascade)
	for index in 0 .. number_of_longhand_properties {
		id := unsafe { PropertyID(index + int(first_longhand_property_id())) }
		a := actual.raw_property_at_index(index)
		b := expected.raw_property_at_index(index)
		assert (a == unsafe { nil }) == (b == unsafe { nil }), string_from_property_id(id)
		if a == unsafe { nil } { continue }
		x := typed_style_value_logic_from_dom(a) or { panic('actual') }
		y := typed_style_value_logic_from_dom(b) or { panic('oracle') }
		assert x.equals(y), string_from_property_id(id)
		assert actual.is_property_important(id) == expected.is_property_important(id)
		assert actual.is_property_inherited(id) == expected.is_property_inherited(id)
	}
	assert actual.depends_on_viewport_metrics_ == expected.depends_on_viewport_metrics_
	assert actual.font_metrics_depend_on_viewport_metrics_ == expected.font_metrics_depend_on_viewport_metrics_
	assert actual.font_input_depends_on_font_size_ == expected.font_input_depends_on_font_size_
}

fn test_font_size_longhands_reuse_exact_values_and_dependency_flags_for_both_font_policies() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut computer, parent, element, parent_style := longhand_reuse_fixture()
		mut document := parent.document()
		document.set_font_rendering_policy(policy)
		defer { document.finalize() }
		computer.root_element_font_metrics = LengthFontMetrics{font_size: CSSPixels.nearest_value_for(16.13), font_size_unrounded: 16.13}
		computer.root_element_font_metrics_depend_on_viewport_metrics = true
		mut cascade := font_size_unit_cascade()
		computer.begin_computed_property_page_batch()
		defer { computer.end_computed_property_page_batch() }
		_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut cascade)
		_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut cascade)
		key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascade, parent_style, false)
		if retain_font_size_unit_longhands { assert key == none; continue }
		actual_key := key or { panic('relative key') }
		mut probe := computed_properties_with_initial_values()
		assert computer.restore_computed_longhands(actual_key, cascade, mut probe)
		font_size_unit_assert_matches_uncached(probe, computer, element, mut cascade)
		assert (probe.property(.width, .no) or { panic('width') }).css_text == '78.75px'
		assert probe.depends_on_viewport_metrics_
	}
}

fn test_font_size_longhands_guard_fractional_root_size_policy_and_raw_parent_mutation() {
	if retain_font_size_unit_longhands { return }
	for change in ['unrounded-root','root-presence','policy','parent-payload','own-payload'] {
		mut computer, parent, element, parent_style := longhand_reuse_fixture()
		mut document := parent.document()
		defer { document.finalize() }
		computer.root_element_font_metrics = LengthFontMetrics{font_size: CSSPixels.new(16), font_size_unrounded: 16.0001}
		mut cascade := font_size_unit_cascade()
		computer.begin_computed_property_page_batch()
		defer { computer.end_computed_property_page_batch() }
		_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut cascade)
		_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut cascade)
		key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascade, parent_style, false) or { panic('key') }
		mut probe := computed_properties_with_initial_values()
		assert computer.restore_computed_longhands(key, cascade, mut probe)
		if change == 'unrounded-root' { computer.root_element_font_metrics.font_size_unrounded = 16.0002 }
		if change == 'root-presence' { computer.root_element_font_metrics.font_size_unrounded = none }
		if change == 'policy' { document.set_font_rendering_policy(.chromium) }
		if change == 'parent-payload' {
			value := parent_style.property(.font_size, .no) or { panic('parent font') }
			mut box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
			box.value = StyleValue(LengthStyleValue.create(Length.make_px(23.25)))
		}
		if change == 'own-payload' {
			value := cascade.style_property(.width) or { panic('width') }
			mut box := unsafe { &TypedStyleValueBox(value.value.css_value_handle) }
			box.value = StyleValue(LengthStyleValue.create(Length.new(4.25, .em)))
		}
		if changed := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascade, parent_style, false) {
			assert !computer.restore_computed_longhands(changed, cascade, mut probe), change
		}
		actual := computer.compute_properties(dom.AbstractElement.new(element, none), mut cascade)
		font_size_unit_assert_matches_uncached(actual, computer, element, mut cascade)
	}
}

fn test_font_size_longhands_keep_metric_units_calculations_and_composites_on_full_computation() {
	for text in ['2ch','1lh','1rlh','2ex','1cap','1cqw','calc(1em + 1px)'] {
		value := parse_css_value(ParsingParams{}, text, .width) or { panic('value') }
		assert !computed_longhand_reuse_property_is_simple(.width, value), text
	}
	value := parse_css_value(ParsingParams{}, '1.5ch', .border_top_left_radius) or { panic('radius') }
	assert !computed_longhand_reuse_property_is_simple(.border_top_left_radius, value)
}

fn test_font_size_longhand_hits_keep_current_specified_owners_after_batch_retirement() {
	if retain_font_size_unit_longhands { return }
	computer, parent, element, parent_style := longhand_reuse_fixture()
	defer { parent.document().finalize() }
	mut original := font_size_unit_cascade()
	mut current := font_size_unit_cascade()
	computer.begin_computed_property_page_batch()
	_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut original)
	_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut original)
	key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), current, parent_style, false) or { panic('key') }
	mut actual := computed_properties_with_initial_values()
	assert computer.restore_computed_longhands(key, current, mut actual)
	font_source := current.style_property(.font_size) or { panic('current font') }
	assert voidptr(actual.raw_cascaded_font_size() or { panic('font source') }) == voidptr(font_source.value)
	for id, source in actual.inheritance_specified_storage_.values {
		property := current.style_property(id) or { panic('current relative input') }
		assert voidptr(source) == voidptr(property.value)
	}
	computer.end_computed_property_page_batch()
	gc_collect()
	// Mutate the old declaration graph after the cache has retired. Neither
	// the retained sources nor a later inherited refresh may read that graph.
	old := original.style_property(.font_size) or { panic('old font') }
	mut old_box := unsafe { &TypedStyleValueBox(old.value.css_value_handle) }
	old_box.value = StyleValue(LengthStyleValue.create(Length.new(100, .em)))
	mut abstract := dom.AbstractElement.new(element, none)
	abstract.set_computed_properties(computed_properties_to_dom(actual))
	mut parent_values := unsafe { &ComputedProperties(parent_style) }
	parent_values.set_property(.font_size, dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(23.25)))), .no, .no)
	_ = computer.recompute_inherited_style_with_invalidation(mut abstract)
	font_size_unit_assert_matches_uncached(actual, computer, element, mut current)
}
