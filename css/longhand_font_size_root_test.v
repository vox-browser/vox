module css

import dom

fn test_font_size_root_live_fractional_guard_matches_each_rendering_policy() {
	if retain_font_size_unit_longhands { return }
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut computer, parent, element, parent_style := longhand_reuse_fixture()
		mut document := parent.document()
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		mut root := document.create_element('html') or { panic(err) }
		mut root_node := root.as_node()
		root_node.append_child(parent.as_node()) or { panic(err) }
		mut document_node := document.as_node()
		document_node.append_child(root_node) or { panic(err) }
		mut root_style := computed_properties_with_initial_values()
		value := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(16.0001))))
		root_style.set_property(.font_size, value, .no, .no)
		mut root_abstract := dom.AbstractElement.new(root, none)
		root_abstract.set_computed_properties(computed_properties_to_dom(root_style))
		computer.root_element_font_metrics = LengthFontMetrics{font_size: CSSPixels.new(16), font_size_unrounded: 16.0001}
		mut cascade := font_size_unit_cascade()
		computer.begin_computed_property_page_batch()
		_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut cascade)
		_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut cascade)
		key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascade, parent_style, false) or { panic('live root key') }
		mut probe := computed_properties_with_initial_values()
		assert computer.restore_computed_longhands(key, cascade, mut probe)
		before := root_style.font_size()
		// Bypass the graph revision and keep the rounded CSSPixels size equal.
		// Generic rem resolution reads the live root, while the font-property
		// context can still read the StyleComputer's cached root metrics.
		mut box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
		box.value = StyleValue(LengthStyleValue.create(Length.make_px(16.0002)))
		assert root_style.font_size() == before
		changed := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascade, parent_style, false)
		if policy == .chromium { assert changed == none }
		else { assert computer.restore_computed_longhands(changed or { panic('same effective root size') }, cascade, mut probe) }
		actual := computer.compute_properties(dom.AbstractElement.new(element, none), mut cascade)
		font_size_unit_assert_matches_uncached(actual, computer, element, mut cascade)
		computer.end_computed_property_page_batch()
		// A later independent batch may admit the new environment again.
		computer.begin_computed_property_page_batch()
		assert computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascade, parent_style, false) == none
		assert computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascade, parent_style, false) != none
		computer.end_computed_property_page_batch()
	}
}

fn test_font_size_root_admission_is_bounded_and_released_with_its_batch() {
	if retain_font_size_unit_longhands { return }
	computer, parent, element, _ := longhand_reuse_fixture()
	defer { parent.document().finalize() }
	computer.begin_computed_property_page_batch()
	for index in 1 .. 601 {
		mut cascade := longhand_reuse_cascade(dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.new(f64(index), .em)))))
		_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut cascade)
	}
	assert computer.longhand_reuse_cache_.font_size_unit_seen.len == 512
	assert computer.longhand_reuse_cache_.entries.len == 0
	computer.end_computed_property_page_batch()
	assert computer.longhand_reuse_cache_ == unsafe { nil }
}
