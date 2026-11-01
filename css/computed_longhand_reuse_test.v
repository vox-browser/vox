module css

import dom
import math

fn longhand_reuse_rgb_value() StyleValue {
	return StyleValue(RGBColorStyleValue.create(StyleValue(NumberStyleValue.create(10)),
		StyleValue(NumberStyleValue.create(20)), StyleValue(NumberStyleValue.create(30)),
		StyleValue(NumberStyleValue.create(0.5)), .modern, none))
}

fn test_longhand_reuse_rgb_snapshots_guard_components_syntax_and_optional_name() {
	original := longhand_reuse_rgb_value()
	snapshot := computed_longhand_reuse_typed_snapshot(&original)
	for field in 0 .. 7 {
		// Each fixture owns distinct channel arrays.
		mut changed := longhand_reuse_rgb_value()
		assert computed_longhand_reuse_typed_snapshot_matches(snapshot, &changed)
		if mut changed is RGBColorStyleValue {
			match field {
				0 { changed.r_[0] = StyleValue(NumberStyleValue.create(11)) }
				1 { changed.g_[0] = StyleValue(NumberStyleValue.create(21)) }
				2 { changed.b_[0] = StyleValue(NumberStyleValue.create(31)) }
				3 { changed.alpha_[0] = StyleValue(NumberStyleValue.create(0.6)) }
				4 { changed.color_syntax_ = .legacy }
				5 { changed.name_ = 'named' }
				else { changed.name_ = '' }
			}
		}
		assert !computed_longhand_reuse_typed_snapshot_matches(snapshot, &changed)
	}
}

fn test_longhand_reuse_rgb_hashes_equal_independent_values_without_losing_channel_types() {
	first := StyleValue(RGBColorStyleValue.create(StyleValue(NumberStyleValue.create(255)),
		StyleValue(NumberStyleValue.create(0)), StyleValue(NumberStyleValue.create(0)), none, .modern, none))
	second := StyleValue(RGBColorStyleValue.create(StyleValue(NumberStyleValue.create(255)),
		StyleValue(NumberStyleValue.create(0)), StyleValue(NumberStyleValue.create(0)), none, .modern, none))
	percentage := StyleValue(RGBColorStyleValue.create(StyleValue(PercentageStyleValue.create(Percentage.new(100))),
		StyleValue(NumberStyleValue.create(0)), StyleValue(NumberStyleValue.create(0)), none, .modern, none))
	snapshot := computed_longhand_reuse_typed_snapshot(&first)
	first_hash := computed_longhand_reuse_typed_hash(&first) or { panic('first RGB hash') }
	second_hash := computed_longhand_reuse_typed_hash(&second) or { panic('second RGB hash') }
	assert first_hash == second_hash
	assert computed_longhand_reuse_typed_snapshot_matches(snapshot, &second)
	assert first.serialize(.normal) == percentage.serialize(.normal)
	assert !computed_longhand_reuse_typed_snapshot_matches(snapshot, &percentage)
	assert !computed_longhand_reuse_typed_snapshot_matches(snapshot,
		StyleValue(ColorStyleValue.create(Color.rgba(255, 0, 0, 255))))
}

fn test_longhand_reuse_rgb_matches_uncached_computation_and_rejects_mutated_retained_input() {
	computer, _, element, parent_style := longhand_reuse_fixture()
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	mut first := CascadedProperties.new()
	color := dom_style_value_from_value_logic(longhand_reuse_rgb_value())
	first.set_property(.background_color, color, .yes, .author, none, unsafe { nil }, none)
	_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut first)
	mut second := CascadedProperties.new()
	second.set_property(.background_color, dom_style_value_from_value_logic(longhand_reuse_rgb_value()),
		.yes, .author, none, unsafe { nil }, none)
	key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), second,
		parent_style, false) or { panic('independent RGB inputs must be eligible') }
	mut probe := computed_properties_with_initial_values()
	assert computer.restore_computed_longhands(key, second, mut probe)
	actual := computer.compute_properties(dom.AbstractElement.new(element, none), mut second)
	longhand_reuse_assert_oracle(actual, computer, element, mut second)
	mut box := unsafe { &TypedStyleValueBox(color.css_value_handle) }
	if mut box.value is RGBColorStyleValue {
		box.value.r_[0] = StyleValue(NumberStyleValue.create(99))
	} else { panic('RGB expected') }
	assert !computer.restore_computed_longhands(key, second, mut probe)
	updated := computer.compute_properties(dom.AbstractElement.new(element, none), mut first)
	longhand_reuse_assert_oracle(updated, computer, element, mut first)
}

fn test_longhand_reuse_rgb_parent_payload_mutations_are_checked_even_after_hash_collision() {
	computer, _, element, parent_style := longhand_reuse_fixture()
	mut parent := unsafe { parent_style }
	color := dom_style_value_from_value_logic(longhand_reuse_rgb_value())
	parent.set_property(.color, color, .no, .no)
	mut cascaded := longhand_reuse_cascade(parse_css_value(ParsingParams{}, '70px', .width) or { panic('width') })
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut cascaded)
	key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascaded,
		parent, false) or { panic('RGB parent') }
	mut probe := computed_properties_with_initial_values()
	assert computer.restore_computed_longhands(key, cascaded, mut probe)
	mut box := unsafe { &TypedStyleValueBox(color.css_value_handle) }
	if mut box.value is RGBColorStyleValue {
		box.value.alpha_[0] = StyleValue(NumberStyleValue.create(0.25))
	} else { panic('RGB expected') }
	assert !computer.restore_computed_longhands(key, cascaded, mut probe)
	actual := computer.compute_properties(dom.AbstractElement.new(element, none), mut cascaded)
	longhand_reuse_assert_oracle(actual, computer, element, mut cascaded)
}

fn test_longhand_reuse_rgb_excludes_context_dependent_and_malformed_channels() {
	for count in [0, 2] {
		mut malformed := longhand_reuse_rgb_value()
		if mut malformed is RGBColorStyleValue {
			malformed.r_ = []StyleValue{len: count, init: StyleValue(NumberStyleValue.create(10))}
		}
		assert !computed_longhand_reuse_typed_value_is_simple(&malformed)
		assert computed_longhand_reuse_typed_hash(&malformed) == none
		assert !computed_longhand_reuse_typed_snapshot_matches(computed_longhand_reuse_typed_snapshot(&malformed), &malformed)
	}
	mut relative := longhand_reuse_rgb_value()
	if mut relative is RGBColorStyleValue {
		relative.r_[0] = StyleValue(LengthStyleValue.create(Length.new(1, .em)))
	}
	assert !computed_longhand_reuse_typed_value_is_simple(&relative)
	assert computed_longhand_reuse_typed_hash(&relative) == none
	calculated := parse_css_value(ParsingParams{}, 'calc(1em + 1px)', .width) or { panic('calculation') }
	if mut relative is RGBColorStyleValue {
		relative.r_[0] = typed_style_value_logic_from_dom(calculated) or { panic('typed calculation') }
	}
	assert !computed_longhand_reuse_typed_value_is_simple(&relative)
	assert computed_longhand_reuse_typed_hash(&relative) == none
}

fn test_longhand_reuse_color_control_preserves_original_parent_identity_and_border_eligibility() {
	previous := computed_longhand_color_mode
	computed_longhand_color_mode = 2
	defer { computed_longhand_color_mode = previous }
	value := longhand_reuse_rgb_value()
	assert !computed_longhand_reuse_typed_value_is_simple(&value)
	assert computed_longhand_reuse_typed_hash(&value) == none
	border := StyleValue(BorderImageSliceStyleValue.create(StyleValue(NumberStyleValue.create(10)),
		StyleValue(NumberStyleValue.create(20)), StyleValue(NumberStyleValue.create(30)),
		StyleValue(NumberStyleValue.create(40)), false))
	assert computed_longhand_reuse_typed_value_is_simple(&border)
}

fn longhand_reuse_fixture() (&StyleComputer, &dom.Element, &dom.Element, &ComputedProperties) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	mut parent := document.create_element('div') or { panic(err) }
	child := document.create_element('span') or { panic(err) }
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic(err) }
	parent.set_attribute_value('style', 'font-size:20px;color:red')
	computer := StyleComputer.new(document)
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	style := computer.compute_style(parent_abstract)
	parent_abstract.set_computed_properties(computed_properties_to_dom(style))
	return computer, parent, child, style
}

fn longhand_reuse_cascade(value &dom.StyleValue) &CascadedProperties {
	mut cascaded := CascadedProperties.new()
	cascaded.set_property(.width, value, .yes, .author, none, unsafe { nil }, none)
	return cascaded
}

// Compare the complete computed result with the ordinary, uncached path.
// Assert individual values so a failure never formats a DOM owner graph.
fn longhand_reuse_assert_oracle(actual &ComputedProperties, computer &StyleComputer,
	element &dom.Element, mut cascaded CascadedProperties) {
	oracle_computer := StyleComputer.new(computer.document_)
	oracle := oracle_computer.compute_properties(dom.AbstractElement.new(element, none), mut cascaded)
	for index in 0 .. number_of_longhand_properties {
		id := unsafe { PropertyID(index + int(first_longhand_property_id())) }
		left := actual.raw_property_at_index(index)
		right := oracle.raw_property_at_index(index)
		assert (left == unsafe { nil }) == (right == unsafe { nil }), string_from_property_id(id)
		if left == unsafe { nil } { continue }
		left_value := typed_style_value_logic_from_dom(left) or { panic('missing actual typed value') }
		right_value := typed_style_value_logic_from_dom(right) or { panic('missing oracle typed value') }
		assert left_value.equals(right_value), string_from_property_id(id)
		assert actual.is_property_inherited(id) == oracle.is_property_inherited(id), string_from_property_id(id)
		assert actual.is_property_important(id) == oracle.is_property_important(id), string_from_property_id(id)
	}
	assert actual.depends_on_viewport_metrics_ == oracle.depends_on_viewport_metrics_
	assert actual.font_metrics_depend_on_viewport_metrics_ == oracle.font_metrics_depend_on_viewport_metrics_
}

fn test_longhand_reuse_accepts_explicit_inheritance_of_guarded_parent_properties() {
	computer, parent, element, parent_style := longhand_reuse_fixture()
	other := parent.document().create_element('span') or { panic(err) }
	mut parent_node := parent.as_node()
	parent_node.append_child(other.as_node()) or { panic(err) }
	mut cascaded := longhand_reuse_cascade(parse_css_value(ParsingParams{}, '70px', .width) or {
		panic('width')
	})
	for id in [PropertyID.font_family, .color, .font_size, .line_height] {
		cascaded.set_property(id, dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.inherit))),
			.no, .author, none, unsafe { nil }, none)
	}
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut cascaded)
	key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(other, none), cascaded,
		parent_style, false) or { panic('inherited declarations must be eligible') }
	mut probe := computed_properties_with_initial_values()
	assert computer.restore_computed_longhands(key, cascaded, mut probe)
	actual := computer.compute_properties(dom.AbstractElement.new(other, none), mut cascaded)
	longhand_reuse_assert_oracle(actual, computer, other, mut cascaded)
	// A forced hash collision still checks the inherited payload, even though
	// both declarations continue to contain the same `inherit` keyword.
	color := parent_style.property(.color, .no) or { panic('color') }
	mut box := unsafe { &TypedStyleValueBox(color.css_value_handle) }
	box.value = StyleValue(ColorStyleValue.create(Color.rgba(7, 8, 9, 255)))
	assert !computer.restore_computed_longhands(key, cascaded, mut probe)
	updated := computer.compute_properties(dom.AbstractElement.new(other, none), mut cascaded)
	longhand_reuse_assert_oracle(updated, computer, other, mut cascaded)
}

fn test_longhand_reuse_wide_defaults_match_uncached_values_and_flags() {
	computer, _, element, parent_style := longhand_reuse_fixture()
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	for keyword in [Keyword.initial, .unset] {
		mut cascaded := CascadedProperties.new()
		for id in [PropertyID.width, .font_family, .color, .line_height] {
			cascaded.set_property(id, dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(keyword))),
				.yes, .author, none, unsafe { nil }, none)
		}
		_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut cascaded)
		key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascaded,
			parent_style, false) or { panic('wide defaults must be eligible') }
		mut probe := computed_properties_with_initial_values()
		assert computer.restore_computed_longhands(key, cascaded, mut probe)
		actual := computer.compute_properties(dom.AbstractElement.new(element, none), mut cascaded)
		longhand_reuse_assert_oracle(actual, computer, element, mut cascaded)
	}
	mut inherited_width := longhand_reuse_cascade(dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.inherit))))
	assert computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none),
		inherited_width, parent_style, false) == none
}

fn test_longhand_reuse_border_slices_match_oracle_and_guard_all_mutable_sides() {
	computer, _, element, parent_style := longhand_reuse_fixture()
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	for side in 0 .. 5 {
		mut cascaded := longhand_reuse_cascade(parse_css_value(ParsingParams{}, '70px', .width) or {
			panic('width')
		})
		slice := parse_css_value(ParsingParams{}, '10 20% 30 40% fill', .border_image_slice) or {
			panic('slice')
		}
		cascaded.set_property(.border_image_slice, slice, .no, .author, none, unsafe { nil }, none)
		_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut cascaded)
		key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascaded,
			parent_style, false) or { panic('numeric border slices must be eligible') }
		mut probe := computed_properties_with_initial_values()
		assert computer.restore_computed_longhands(key, cascaded, mut probe)
		actual := computer.compute_properties(dom.AbstractElement.new(element, none), mut cascaded)
		longhand_reuse_assert_oracle(actual, computer, element, mut cascaded)
		mut box := unsafe { &TypedStyleValueBox(slice.css_value_handle) }
		if mut box.value is BorderImageSliceStyleValue {
			match side {
				0 { box.value.top_[0] = StyleValue(NumberStyleValue.create(19)) }
				1 { box.value.right_[0] = StyleValue(PercentageStyleValue.create(Percentage.new(29))) }
				2 { box.value.bottom_[0] = StyleValue(NumberStyleValue.create(39)) }
				3 { box.value.left_[0] = StyleValue(PercentageStyleValue.create(Percentage.new(49))) }
				else { box.value.fill_ = false }
			}
		} else { panic('wrong slice type') }
		assert !computer.restore_computed_longhands(key, cascaded, mut probe)
		updated := computer.compute_properties(dom.AbstractElement.new(element, none), mut cascaded)
		longhand_reuse_assert_oracle(updated, computer, element, mut cascaded)
	}
}

fn test_longhand_reuse_border_slice_snapshots_keep_types_and_reject_incomplete_sides() {
	value := StyleValue(BorderImageSliceStyleValue.create(StyleValue(NumberStyleValue.create(10)),
		StyleValue(NumberStyleValue.create(20)), StyleValue(NumberStyleValue.create(30)),
		StyleValue(NumberStyleValue.create(40)), false))
	snapshot := computed_longhand_reuse_typed_snapshot(&value)
	mut changed := value
	if mut changed is BorderImageSliceStyleValue {
		changed.top_ = [StyleValue(PercentageStyleValue.create(Percentage.new(10)))]
	}
	assert !computed_longhand_reuse_typed_snapshot_matches(snapshot, &changed)
	if mut changed is BorderImageSliceStyleValue { changed.top_ = []StyleValue{} }
	assert !computed_longhand_reuse_typed_value_is_simple(&changed)
	assert computed_longhand_reuse_typed_hash(&changed) == none
	assert !computed_longhand_reuse_typed_snapshot_matches(snapshot, &changed)
	if mut changed is BorderImageSliceStyleValue {
		changed.top_ = [StyleValue(LengthStyleValue.create(Length.new(2, .em)))]
	}
	assert !computed_longhand_reuse_typed_value_is_simple(&changed)
}

fn test_longhand_reuse_control_keeps_original_keyword_and_composite_eligibility() {
	previous := computed_longhand_extension_mode
	computed_longhand_extension_mode = 2
	defer { computed_longhand_extension_mode = previous }
	for keyword in [Keyword.inherit, .initial, .unset] {
		value := dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(keyword)))
		assert !computed_longhand_reuse_property_is_simple(.font_family, value)
	}
	value := StyleValue(BorderImageSliceStyleValue.create(StyleValue(NumberStyleValue.create(10)),
		StyleValue(NumberStyleValue.create(20)), StyleValue(NumberStyleValue.create(30)),
		StyleValue(NumberStyleValue.create(40)), false))
	assert !computed_longhand_reuse_typed_value_is_simple(&value)
	assert computed_longhand_reuse_typed_value_is_simple(&StyleValue(NumberStyleValue.create(10)))
}

fn test_longhand_reuse_matches_full_computation_and_keeps_sibling_ownership() {
	computer, parent, first_element, _ := longhand_reuse_fixture()
	second_element := parent.document().create_element('span') or { panic(err) }
	mut parent_node := parent.as_node()
	parent_node.append_child(second_element.as_node()) or { panic(err) }
	width := parse_css_value(ParsingParams{}, '70px', .width) or { panic('width') }
	mut cascaded := longhand_reuse_cascade(width)
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	mut first := computer.compute_properties(dom.AbstractElement.new(first_element, none), mut cascaded)
	key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(second_element, none),
		cascaded, parent_computed_properties(dom.AbstractElement.new(second_element, none)), false) or {
		panic('simple siblings must be eligible')
	}
	mut probe := computed_properties_with_initial_values()
	assert computer.restore_computed_longhands(key, cascaded, mut probe)
	second := computer.compute_properties(dom.AbstractElement.new(second_element, none), mut cascaded)
	longhand_reuse_assert_oracle(first, computer, first_element, mut cascaded)
	longhand_reuse_assert_oracle(second, computer, second_element, mut cascaded)
	assert voidptr(first.subject_element_ or { panic('missing first subject') }) == voidptr(first_element)
	assert voidptr(second.subject_element_ or { panic('missing second subject') }) == voidptr(second_element)
	assert voidptr(first.property_store_) != voidptr(second.property_store_)
	assert voidptr(first.computed_property_graph_token_) != voidptr(second.computed_property_graph_token_)
	first.set_property(.width, parse_css_value(ParsingParams{}, '93px', .width) or {
		panic('replacement width')
	}, .no, .no)
	longhand_reuse_assert_oracle(second, computer, second_element, mut cascaded)
}

fn test_longhand_reuse_rejects_in_place_parent_and_cascaded_value_mutations() {
	computer, _, element, parent_style := longhand_reuse_fixture()
	width := parse_css_value(ParsingParams{}, '70px', .width) or { panic('width') }
	mut cascaded := longhand_reuse_cascade(width)
	abstract_element := dom.AbstractElement.new(element, none)
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	_ = computer.compute_properties(abstract_element, mut cascaded)
	mut key := computer.computed_longhand_reuse_key(abstract_element, cascaded,
		parent_style, false) or { panic('eligible initial style') }
	mut probe := computed_properties_with_initial_values()
	assert computer.restore_computed_longhands(key, cascaded, mut probe)

	color := parent_style.property(.color, .no) or { panic('parent color') }
	mut color_box := unsafe { &TypedStyleValueBox(color.css_value_handle) }
	replacement := parse_css_value(ParsingParams{}, 'blue', .color) or { panic('blue') }
	color_box.value = typed_style_value_logic_from_dom(replacement) or { panic('blue typed value') }
	// Both wrapper and typed-handle identity survive this payload mutation.
	assert !computer.restore_computed_longhands(key, cascaded, mut probe)
	updated_parent := computer.compute_properties(abstract_element, mut cascaded)
	longhand_reuse_assert_oracle(updated_parent, computer, element, mut cascaded)

	key = computer.computed_longhand_reuse_key(abstract_element, cascaded,
		parent_style, false) or { panic('eligible updated parent') }
	assert computer.restore_computed_longhands(key, cascaded, mut probe)
	mut width_box := unsafe { &TypedStyleValueBox(width.css_value_handle) }
	width_box.value = StyleValue(LengthStyleValue.create(Length.make_px(93)))
	assert !computer.restore_computed_longhands(key, cascaded, mut probe)
	updated_width := computer.compute_properties(abstract_element, mut cascaded)
	longhand_reuse_assert_oracle(updated_width, computer, element, mut cascaded)
}

fn test_longhand_reuse_excludes_relative_lengths_and_expires_at_outer_batch_end() {
	computer, _, element, parent_style := longhand_reuse_fixture()
	abstract_element := dom.AbstractElement.new(element, none)
	mut relative := longhand_reuse_cascade(parse_css_value(ParsingParams{}, '2em', .width) or {
		panic('relative width')
	})
	computer.begin_computed_property_page_batch()
	computer.begin_computed_property_page_batch()
	relative_is_eligible := computer.computed_longhand_reuse_key(abstract_element, relative, parent_style, false) != none
	assert !relative_is_eligible
	computed := computer.compute_properties(abstract_element, mut relative)
	longhand_reuse_assert_oracle(computed, computer, element, mut relative)
	mut absolute := longhand_reuse_cascade(parse_css_value(ParsingParams{}, '70px', .width) or {
		panic('absolute width')
	})
	_ = computer.compute_properties(abstract_element, mut absolute)
	key := computer.computed_longhand_reuse_key(abstract_element, absolute, parent_style, false) or {
		panic('eligible absolute width')
	}
	mut probe := computed_properties_with_initial_values()
	computer.end_computed_property_page_batch()
	assert computer.restore_computed_longhands(key, absolute, mut probe)
	computer.end_computed_property_page_batch()
	assert !computer.restore_computed_longhands(key, absolute, mut probe)
	outside_batch_is_eligible := computer.computed_longhand_reuse_key(abstract_element, absolute, parent_style, false) != none
	assert !outside_batch_is_eligible
}

fn test_longhand_reuse_ignores_noninherited_parent_values_but_guards_inherited_payloads() {
	computer, parent, first_element, parent_style := longhand_reuse_fixture()
	mut other_parent := parent.document().create_element('div') or { panic(err) }
	other_element := parent.document().create_element('span') or { panic(err) }
	mut other_node := other_parent.as_node()
	other_node.append_child(other_element.as_node()) or { panic(err) }
	mut other_style := &ComputedProperties{
		...parent_style
		property_store_:                parent_style.clone_raw_property_store()
		computed_property_graph_token_: unsafe { nil }
	}
	// These changes replace COW pages containing inherited inputs as well.
	for name, text in {
		'width':            '123px'
		'background-color': 'blue'
		'margin-left':      '19px'
	} {
		id := property_id_from_string(name) or { panic(name) }
		other_style.set_property(id, parse_css_value(ParsingParams{}, text, id) or {
			panic(name)
		}, .no, .no)
	}
	mut other_abstract := dom.AbstractElement.new(other_parent, none)
	other_abstract.set_computed_properties(computed_properties_to_dom(other_style))
	mut cascaded := longhand_reuse_cascade(parse_css_value(ParsingParams{}, '70px', .width) or {
		panic('child width')
	})
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	_ = computer.compute_properties(dom.AbstractElement.new(first_element, none), mut cascaded)
	key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(other_element, none),
		cascaded, other_style, false) or { panic('equivalent inherited inputs') }
	mut probe := computed_properties_with_initial_values()
	assert computer.restore_computed_longhands(key, cascaded, mut probe)
	actual := computer.compute_properties(dom.AbstractElement.new(other_element, none), mut cascaded)
	longhand_reuse_assert_oracle(actual, computer, other_element, mut cascaded)

	background := other_style.property(.background_color, .no) or { panic('parent background') }
	mut background_box := unsafe { &TypedStyleValueBox(background.css_value_handle) }
	background_box.value = StyleValue(ColorStyleValue.create(Color.rgba(0, 255, 0, 255)))
	assert computer.restore_computed_longhands(key, cascaded, mut probe)
	longhand_reuse_assert_oracle(actual, computer, other_element, mut cascaded)

	color := other_style.property(.color, .no) or { panic('inherited color') }
	mut color_box := unsafe { &TypedStyleValueBox(color.css_value_handle) }
	color_box.value = StyleValue(ColorStyleValue.create(Color.rgba(0, 0, 255, 255)))
	assert !computer.restore_computed_longhands(key, cascaded, mut probe)
}

fn test_longhand_reuse_guards_absent_inherited_inputs_even_with_a_hash_collision() {
	computer, _, element, parent_style := longhand_reuse_fixture()
	mut parent := unsafe { &ComputedProperties(parent_style) }
	color_index := int(PropertyID.color) - int(first_longhand_property_id())
	parent.set_raw_property_at_index(color_index, unsafe { nil })
	mut cascaded := longhand_reuse_cascade(parse_css_value(ParsingParams{}, '70px', .width) or {
		panic('child width')
	})
	abstract_element := dom.AbstractElement.new(element, none)
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	_ = computer.compute_properties(abstract_element, mut cascaded)
	key := computer.computed_longhand_reuse_key(abstract_element, cascaded, parent, false) or {
		panic('eligible absent inherited value')
	}
	mut probe := computed_properties_with_initial_values()
	assert computer.restore_computed_longhands(key, cascaded, mut probe)
	parent.set_property(.color, parse_css_value(ParsingParams{}, 'red', .color) or {
		panic('parent color')
	}, .no, .no)
	changed_key := computer.computed_longhand_reuse_key(abstract_element, cascaded, parent, false) or {
		panic('eligible present inherited value')
	}
	// Deliberately collide the lookup hash to exercise the complete input guard.
	collision_key := ComputedLonghandReuseKey{ ...changed_key, hash: key.hash }
	assert !computer.restore_computed_longhands(collision_key, cascaded, mut probe)
}

fn test_longhand_reuse_accepts_equal_payloads_in_distinct_parent_and_cascade_boxes() {
	computer, parent, element, parent_style := longhand_reuse_fixture()
	// Keep this scalar fixture distinct from the parsed RGB channel tests.
	mut scalar_parent := unsafe { parent_style }
	scalar_parent.set_property(.color, dom_style_value_from_value_logic(
		StyleValue(ColorStyleValue.create(Color.rgba(255, 0, 0, 255)))), .no, .no)
	mut other_parent := parent.document().create_element('div') or { panic(err) }
	other_element := parent.document().create_element('span') or { panic(err) }
	mut other_node := other_parent.as_node()
	other_node.append_child(other_element.as_node()) or { panic(err) }
	mut other_style := &ComputedProperties{
		...parent_style
		property_store_:                parent_style.clone_raw_property_store()
		computed_property_graph_token_: unsafe { nil }
	}
	for id, text in {
		PropertyID.font_size: '20px'
		PropertyID.color:     'rgb(255, 0, 0)'
	} {
		replacement := if id == .color {
			dom_style_value_from_value_logic(StyleValue(ColorStyleValue.create(Color.rgba(255, 0, 0, 255))))
		} else {
			parse_css_value(ParsingParams{}, text, id) or { panic(text) }
		}
		original := parent_style.property(id, .no) or { panic(text) }
		original_typed := typed_style_value_logic_from_dom(original) or { panic('original') }
		replacement_typed := typed_style_value_logic_from_dom(replacement) or { panic('replacement') }
		assert original_typed.equals(replacement_typed)
		assert voidptr(original) != voidptr(replacement)
		assert original.css_value_handle != replacement.css_value_handle
		other_style.set_property(id, replacement, .no, .no)
	}
	mut other_abstract := dom.AbstractElement.new(other_parent, none)
	other_abstract.set_computed_properties(computed_properties_to_dom(other_style))
	mut first_cascade := longhand_reuse_cascade(parse_css_value(ParsingParams{}, '70px', .width) or {
		panic('first width')
	})
	mut second_cascade := longhand_reuse_cascade(parse_css_value(ParsingParams{}, '70px', .width) or {
		panic('second width')
	})
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut first_cascade)
	first_key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none),
		first_cascade, parent_style, false) or { panic('first key') }
	key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(other_element, none),
		second_cascade, other_style, false) or { panic('equal independently boxed inputs') }
	assert key.hash == first_key.hash
	mut probe := computed_properties_with_initial_values()
	assert computer.restore_computed_longhands(key, second_cascade, mut probe)
	actual := computer.compute_properties(dom.AbstractElement.new(other_element, none), mut second_cascade)
	longhand_reuse_assert_oracle(actual, computer, other_element, mut second_cascade)
	// The saved scalar is a copy, even when the matching box is a different one.
	color := other_style.property(.color, .no) or { panic('color') }
	mut box := unsafe { &TypedStyleValueBox(color.css_value_handle) }
	box.value = StyleValue(ColorStyleValue.create(Color.rgba(0, 0, 255, 255)))
	assert !computer.restore_computed_longhands(key, second_cascade, mut probe)
}

fn test_longhand_reuse_semantic_lists_keep_nested_payload_and_type_guards() {
	child := StyleValue(NumberStyleValue.create(1))
	first := StyleValue(StyleValueList.create_collapsible([child], .comma))
	second := StyleValue(StyleValueList.create_collapsible([StyleValue(NumberStyleValue.create(1))], .comma))
	snapshot := computed_longhand_reuse_typed_snapshot(first)
	first_hash := computed_longhand_reuse_typed_hash(&first) or { panic('first list hash') }
	second_hash := computed_longhand_reuse_typed_hash(&second) or { panic('second list hash') }
	assert first_hash == second_hash
	assert computed_longhand_reuse_typed_snapshot_matches(&snapshot, second)
	// Identical serialization cannot stand in for typed payload equality.
	different_type := StyleValue(StyleValueList.create_collapsible([StyleValue(IntegerStyleValue.create(1))], .comma))
	assert first.serialize(.normal) == different_type.serialize(.normal)
	assert !computed_longhand_reuse_typed_snapshot_matches(&snapshot, different_type)
	different_separator := StyleValue(StyleValueList.create_collapsible([child], .space))
	assert !computed_longhand_reuse_typed_snapshot_matches(&snapshot, different_separator)
	different_collapsibility := StyleValue(StyleValueList.create([child], .comma, .no))
	assert !computed_longhand_reuse_typed_snapshot_matches(&snapshot, different_collapsibility)
	mut mutable := second
	if mut mutable is StyleValueList {
		mutable.values_[0] = StyleValue(NumberStyleValue.create(2))
	}
	assert !computed_longhand_reuse_typed_snapshot_matches(&snapshot, mutable)
	assert computed_longhand_reuse_number_hash(0.0) == computed_longhand_reuse_number_hash(-0.0)
}

fn test_longhand_reuse_scalar_snapshots_freeze_every_supported_payload() {
	// The saved record must remain much smaller than the full style-value union.
	assert sizeof(ComputedLonghandReuseValue) < sizeof(StyleValue)
	values := [StyleValue(KeywordStyleValue.create(.auto)),
		StyleValue(LengthStyleValue.create(Length.new(3, .cm))),
		StyleValue(ColorStyleValue.create(Color.rgba(1, 2, 3, 4))),
		StyleValue(NumberStyleValue.create(3.25)), StyleValue(IntegerStyleValue.create(-7)),
		StyleValue(PercentageStyleValue.create(Percentage.new(12.5))),
		StyleValue(DisplayStyleValue.create(Display.from_outside_inside(.inline_, .flex))),
		StyleValue(StringStyleValue.create('text')),
		StyleValue(CustomIdentStyleValue.create('custom'))]
	for original in values {
		wrapper := dom_style_value_from_value_logic(original)
		mut box := unsafe { &TypedStyleValueBox(wrapper.css_value_handle) }
		snapshot := computed_longhand_reuse_typed_snapshot(&box.value)
		assert computed_longhand_reuse_typed_snapshot_matches(&snapshot, &box.value)
		match mut box.value {
			KeywordStyleValue { box.value.keyword_ = .none_ }
			LengthStyleValue { box.value.length_.unit_ = .px }
			ColorStyleValue { box.value.color_.a = 255 }
			NumberStyleValue { box.value.value_ += 1 }
			IntegerStyleValue { box.value.value_ += 1 }
			PercentageStyleValue { box.value.percentage_.value_ += 1 }
			DisplayStyleValue { box.value.display_.list_item = .yes }
			StringStyleValue { box.value.string_value_ = 'changed' }
			CustomIdentStyleValue { box.value.custom_ident_ = 'changed' }
			else { panic('unsupported scalar fixture') }
		}
		assert !computed_longhand_reuse_typed_snapshot_matches(&snapshot, &box.value)
	}
	for value in [StyleValue(NumberStyleValue.create(math.nan())),
		StyleValue(LengthStyleValue.create(Length.make_px(math.nan()))),
		StyleValue(PercentageStyleValue.create(Percentage.new(math.nan())))] {
		snapshot := computed_longhand_reuse_typed_snapshot(&value)
		assert !computed_longhand_reuse_typed_snapshot_matches(&snapshot, &value)
	}
	positive := StyleValue(NumberStyleValue.create(0.0))
	negative := StyleValue(NumberStyleValue.create(-0.0))
	snapshot := computed_longhand_reuse_typed_snapshot(&positive)
	assert computed_longhand_reuse_typed_snapshot_matches(&snapshot, &negative)
	assert !computed_longhand_reuse_typed_snapshot_matches(&snapshot,
		StyleValue(IntegerStyleValue.create(0)))
}

fn constant_longhand_value(id PropertyID) StyleValue {
	return match id {
		.aspect_ratio { StyleValue(RatioStyleValue.create(Ratio.new(16, 9))) }
		.font_style { StyleValue(FontStyleStyleValue.create(.normal, none)) }
		else { StyleValue(TimeStyleValue.create(Time.new(0.5, .s))) }
	}
}

fn mutate_constant_longhand_value(mut value StyleValue) {
	match mut value {
		RatioStyleValue { value.numerator_[0] = StyleValue(NumberStyleValue.create(17)) }
		FontStyleStyleValue { value.font_style_ = .italic }
		TimeStyleValue { value.time_.value_ = 0.75 }
		else { panic('expected constant longhand') }
	}
}

fn test_constant_longhands_reuse_independent_values_and_reject_retained_mutations() {
	previous := computed_longhand_constant_mode
	computed_longhand_constant_mode = 1
	defer { computed_longhand_constant_mode = previous }
	for id in [PropertyID.aspect_ratio, .font_style, .transition_duration] {
		computer, _, element, parent_style := longhand_reuse_fixture()
		computer.begin_computed_property_page_batch()
		mut first := CascadedProperties.new()
		original := dom_style_value_from_value_logic(constant_longhand_value(id))
		first.set_property(id, original, .yes, .author, none, unsafe { nil }, none)
		_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut first)
		mut second := CascadedProperties.new()
		second.set_property(id, dom_style_value_from_value_logic(constant_longhand_value(id)),
			.yes, .author, none, unsafe { nil }, none)
		key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), second,
			parent_style, false) or { panic('constant input must be eligible') }
		mut probe := computed_properties_with_initial_values()
		assert computer.restore_computed_longhands(key, second, mut probe), string_from_property_id(id)
		actual := computer.compute_properties(dom.AbstractElement.new(element, none), mut second)
		longhand_reuse_assert_oracle(actual, computer, element, mut second)
		mut box := unsafe { &TypedStyleValueBox(original.css_value_handle) }
		mutate_constant_longhand_value(mut box.value)
		assert !computer.restore_computed_longhands(key, second, mut probe), string_from_property_id(id)
		updated := computer.compute_properties(dom.AbstractElement.new(element, none), mut first)
		longhand_reuse_assert_oracle(updated, computer, element, mut first)
		computer.end_computed_property_page_batch()
	}
}

fn test_constant_longhand_snapshots_keep_ratio_components_and_time_units_distinct() {
	ratio := StyleValue(RatioStyleValue.create(Ratio.new(16, 9)))
	ratio_snapshot := computed_longhand_reuse_typed_snapshot(&ratio)
	assert computed_longhand_reuse_typed_snapshot_matches(ratio_snapshot,
		StyleValue(RatioStyleValue.create(Ratio.new(16, 9)) ))
	for changed in [
		StyleValue(RatioStyleValue.create(Ratio.new(32, 18))),
		StyleValue(RatioStyleValue.create(Ratio.new(16, 10))),
		StyleValue(RatioStyleValue.create_from_style_values(StyleValue(IntegerStyleValue.create(16)),
			StyleValue(NumberStyleValue.create(9)))),
	] {
		assert !computed_longhand_reuse_typed_snapshot_matches(ratio_snapshot, &changed)
	}
	time := StyleValue(TimeStyleValue.create(Time.new(0.5, .s)))
	time_snapshot := computed_longhand_reuse_typed_snapshot(&time)
	assert computed_longhand_reuse_typed_snapshot_matches(time_snapshot,
		StyleValue(TimeStyleValue.create(Time.new(0.5, .s))))
	for changed in [StyleValue(TimeStyleValue.create(Time.new(0.5, .ms))),
		StyleValue(TimeStyleValue.create(Time.new(500, .ms))), StyleValue(NumberStyleValue.create(0.5))] {
		assert !computed_longhand_reuse_typed_snapshot_matches(time_snapshot, &changed)
	}
}

fn test_constant_longhand_snapshots_distinguish_font_angle_presence_from_serialization() {
	normal := StyleValue(FontStyleStyleValue.create(.normal, none))
	snapshot := computed_longhand_reuse_typed_snapshot(&normal)
	oblique := StyleValue(FontStyleStyleValue.create(.oblique,
		StyleValue(AngleStyleValue.create(Angle.new(0, .deg)))))
	assert normal.serialize(.normal) == oblique.serialize(.normal)
	assert !computed_longhand_reuse_typed_snapshot_matches(snapshot, &oblique)
	assert !computed_longhand_reuse_typed_value_is_simple(&oblique)
	assert computed_longhand_reuse_typed_hash(&oblique) == none
	for style in [FontStyleKeyword.italic, .oblique] {
		assert !computed_longhand_reuse_typed_snapshot_matches(snapshot,
			StyleValue(FontStyleStyleValue.create(style, none)))
	}
}

fn test_constant_longhands_reject_calculated_ratios_and_malformed_component_arrays() {
	previous := computed_longhand_constant_mode
	computed_longhand_constant_mode = 1
	defer { computed_longhand_constant_mode = previous }
	calculated := parse_css_value(ParsingParams{}, 'calc(1em + 1px)', .width) or { panic('calculation') }
	value := typed_style_value_logic_from_dom(calculated) or { panic('typed calculation') }
	ratio := StyleValue(RatioStyleValue.create_from_style_values(value,
		StyleValue(NumberStyleValue.create(9))))
	assert !computed_longhand_reuse_typed_value_is_simple(&ratio)
	assert computed_longhand_reuse_typed_hash(&ratio) == none
	for component in 0 .. 2 {
		for count in [0, 2] {
			mut malformed := constant_longhand_value(.aspect_ratio)
			if mut malformed is RatioStyleValue {
				if component == 0 {
					malformed.numerator_ = []StyleValue{len: count, init: StyleValue(NumberStyleValue.create(16))}
				} else {
					malformed.denominator_ = []StyleValue{len: count, init: StyleValue(NumberStyleValue.create(9))}
				}
			}
			assert !computed_longhand_reuse_typed_value_is_simple(&malformed)
			assert computed_longhand_reuse_typed_hash(&malformed) == none
			assert !computed_longhand_reuse_typed_snapshot_matches(computed_longhand_reuse_typed_snapshot(&malformed), &malformed)
		}
	}
}

fn test_constant_font_parent_payload_is_guarded_after_an_in_place_mutation() {
	previous := computed_longhand_constant_mode
	computed_longhand_constant_mode = 1
	defer { computed_longhand_constant_mode = previous }
	computer, _, element, parent_style := longhand_reuse_fixture()
	mut parent := unsafe { parent_style }
	font_style := dom_style_value_from_value_logic(constant_longhand_value(.font_style))
	parent.set_property(.font_style, font_style, .no, .no)
	mut cascaded := longhand_reuse_cascade(parse_css_value(ParsingParams{}, '70px', .width) or { panic('width') })
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut cascaded)
	key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascaded,
		parent, false) or { panic('constant font parent') }
	mut probe := computed_properties_with_initial_values()
	assert computer.restore_computed_longhands(key, cascaded, mut probe)
	mut box := unsafe { &TypedStyleValueBox(font_style.css_value_handle) }
	mutate_constant_longhand_value(mut box.value)
	assert !computer.restore_computed_longhands(key, cascaded, mut probe)
	updated := computer.compute_properties(dom.AbstractElement.new(element, none), mut cascaded)
	longhand_reuse_assert_oracle(updated, computer, element, mut cascaded)
}

fn test_constant_longhand_control_keeps_new_types_ineligible_including_lists() {
	previous := computed_longhand_constant_mode
	computed_longhand_constant_mode = 2
	defer { computed_longhand_constant_mode = previous }
	for id in [PropertyID.aspect_ratio, .font_style, .transition_duration] {
		value := constant_longhand_value(id)
		assert !computed_longhand_reuse_typed_value_is_simple(&value)
		assert computed_longhand_reuse_typed_hash(&value) == none
		list := StyleValue(StyleValueList.create([value], .comma, .yes))
		assert !computed_longhand_reuse_typed_value_is_simple(&list)
		assert computed_longhand_reuse_typed_hash(&list) == none
	}
}

fn test_constant_font_snapshots_guard_angles_and_reject_malformed_storage() {
	for field in 0 .. 4 {
		original := StyleValue(FontStyleStyleValue.create(.oblique,
			StyleValue(AngleStyleValue.create(Angle.new(14, .deg)))))
		snapshot := computed_longhand_reuse_typed_snapshot(&original)
		assert computed_longhand_reuse_typed_snapshot_matches(snapshot, &original)
		mut changed := StyleValue(FontStyleStyleValue.create(.oblique,
			StyleValue(AngleStyleValue.create(Angle.new(14, .deg)))))
		if mut changed is FontStyleStyleValue {
			changed.angle_value_ = match field {
				0 { [StyleValue(AngleStyleValue.create(Angle.new(15, .deg)))] }
				1 { [StyleValue(AngleStyleValue.create(Angle.new(14, .rad)))] }
				2 { []StyleValue{} }
				else { [StyleValue(AngleStyleValue.create(Angle.new(14, .deg))),
					StyleValue(AngleStyleValue.create(Angle.new(14, .deg)))] }
			}
		}
		assert !computed_longhand_reuse_typed_snapshot_matches(snapshot, &changed)
		assert !computed_longhand_reuse_typed_value_is_simple(&changed)
		assert computed_longhand_reuse_typed_hash(&changed) == none
	}
}

fn test_constant_font_parent_guards_distinct_values_with_equal_serialization() {
	computer, _, element, parent_style := longhand_reuse_fixture()
	mut parent := unsafe { parent_style }
	font_style := dom_style_value_from_value_logic(StyleValue(FontStyleStyleValue.create(.oblique,
		StyleValue(AngleStyleValue.create(Angle.new(0, .deg))))))
	parent.set_property(.font_style, font_style, .no, .no)
	mut cascaded := longhand_reuse_cascade(parse_css_value(ParsingParams{}, '70px', .width) or { panic('width') })
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	_ = computer.compute_properties(dom.AbstractElement.new(element, none), mut cascaded)
	key := computer.computed_longhand_reuse_key(dom.AbstractElement.new(element, none), cascaded,
		parent, false) or { panic('angled font parent') }
	mut probe := computed_properties_with_initial_values()
	assert computer.restore_computed_longhands(key, cascaded, mut probe)
	mut box := unsafe { &TypedStyleValueBox(font_style.css_value_handle) }
	normal := constant_longhand_value(.font_style)
	assert box.value.serialize(.normal) == normal.serialize(.normal)
	box.value = normal
	assert !computer.restore_computed_longhands(key, cascaded, mut probe)
	updated := computer.compute_properties(dom.AbstractElement.new(element, none), mut cascaded)
	longhand_reuse_assert_oracle(updated, computer, element, mut cascaded)
}
