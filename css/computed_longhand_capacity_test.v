module css

import dom

fn fill_longhand_capacity(computer &StyleComputer, element &dom.Element, count int) {
	for index in 0 .. count {
		mut cascade := longhand_reuse_cascade(parse_css_value(ParsingParams{}, '${index}px', .width) or { panic('width') })
		_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut cascade)
	}
}

fn test_longhand_capacity_keeps_a_hard_bound_and_reuses_late_styles_against_oracle() {
	computer, _, element, parent := longhand_reuse_fixture()
	computer.begin_computed_property_page_batch()
	fill_longhand_capacity(computer, element, 1032)
	assert computer.longhand_reuse_cache_.entries.len == if retain_small_longhand_cache { 256 } else { 1024 }
	mut cascade := longhand_reuse_cascade(parse_css_value(ParsingParams{}, '1000px', .width) or { panic('late width') })
	key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascade, parent, false) or { panic('late key') }
	mut probe := computed_properties_with_initial_values()
	assert computer.restore_computed_longhands(key, cascade, mut probe) == !retain_small_longhand_cache
	actual := computer.compute_properties(dom.AbstractElement.new(element, none), mut cascade)
	longhand_reuse_assert_oracle(actual, computer, element, mut cascade)
	computer.end_computed_property_page_batch()
	gc_collect()
	assert computer.longhand_reuse_cache_ == unsafe { nil }
	assert (actual.property(.width, .no) or { panic('retained width') }).css_text == '1000px'
	computer.begin_computed_property_page_batch()
	assert computer.longhand_reuse_cache_ == unsafe { nil }
	assert !computer.restore_computed_longhands(key, cascade, mut probe)
	computer.end_computed_property_page_batch()
}

fn test_longhand_capacity_late_entries_keep_exact_mutable_input_and_parent_guards() {
	computer, _, element, parent := longhand_reuse_fixture()
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	fill_longhand_capacity(computer, element, 256)
	value := parse_css_value(ParsingParams{}, '9999px', .width) or { panic('late width') }
	mut cascade := longhand_reuse_cascade(value)
	_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut cascade)
	key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascade, parent, false) or { panic('late key') }
	mut probe := computed_properties_with_initial_values()
	assert computer.restore_computed_longhands(key, cascade, mut probe) == !retain_small_longhand_cache
	mut box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	if mut box.value is LengthStyleValue {
		box.value.length_.value_ = 333
	} else { panic('length expected') }
	assert !computer.restore_computed_longhands(key, cascade, mut probe)
	actual := computer.compute_properties(dom.AbstractElement.new(element, none), mut cascade)
	longhand_reuse_assert_oracle(actual, computer, element, mut cascade)
	new_key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascade, parent, false) or { panic('changed key') }
	mut mutable_parent := unsafe { parent }
	mutable_parent.set_property(.color, dom_style_value_from_value_logic(StyleValue(ColorStyleValue.create(Color.rgba(7, 8, 9, 255)))), .no, .no)
	assert !computer.restore_computed_longhands(new_key, cascade, mut probe)
	updated := computer.compute_properties(dom.AbstractElement.new(element, none), mut cascade)
	longhand_reuse_assert_oracle(updated, computer, element, mut cascade)
}

fn test_longhand_capacity_nested_batches_keep_snapshots_separate_from_mutable_restores() {
	computer, _, element, parent := longhand_reuse_fixture()
	computer.begin_computed_property_page_batch()
	computer.begin_computed_property_page_batch()
	fill_longhand_capacity(computer, element, 256)
	mut cascade := longhand_reuse_cascade(parse_css_value(ParsingParams{}, '9999px', .width) or { panic('late width') })
	_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut cascade)
	key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascade, parent, false) or { panic('late key') }
	computer.end_computed_property_page_batch()
	mut probe := computed_properties_with_initial_values()
	reused := computer.restore_computed_longhands(key, cascade, mut probe)
	assert reused == !retain_small_longhand_cache
	if reused {
		entry := computer.longhand_reuse_cache_.entries[key.hash] or { panic('late entry') }
		assert entry.extended_admission
		before := (entry.computed.property(.height, .no) or { panic('height') }).css_text
		probe.set_property(.height, parse_css_value(ParsingParams{}, '17px', .height) or { panic('height') }, .no, .no)
		assert (entry.computed.property(.height, .no) or { panic('cached height') }).css_text == before
		assert (probe.property(.height, .no) or { panic('changed height') }).css_text == '17px'
	}
	computer.end_computed_property_page_batch()
	gc_collect()
	assert computer.longhand_reuse_cache_ == unsafe { nil }
}
