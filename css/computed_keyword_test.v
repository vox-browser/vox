module css

import dom

fn test_computed_keyword_reads_every_retained_keyword_without_serialized_text() {
	for index in int(Keyword.invalid) + 1 .. int(Keyword.zoom_out) + 1 {
		keyword := unsafe { Keyword(index) }
		mut value := dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(keyword)))
		// Retained types, rather than potentially stale bridge text, are authoritative.
		value.css_text = 'not-a-keyword'
		assert computed_interpolation_style_value_keyword(value)? == keyword
	}
}

fn test_computed_keyword_keeps_nonkeyword_types_and_invalid_keywords_absent() {
	for typed in [StyleValue(CustomIdentStyleValue.create('inherit')),
		StyleValue(StringStyleValue.create('initial')),
		StyleValue(LengthStyleValue.create(Length.make_px(12))),
		StyleValue(KeywordStyleValue.create(.invalid))] {
		mut value := dom_style_value_from_value_logic(typed)
		value.css_text = 'unset'
		assert computed_interpolation_style_value_keyword(value) == none
		assert !computed_interpolation_style_value_is_inherit(value)
		assert !computed_interpolation_style_value_is_initial(value)
		assert !computed_interpolation_style_value_is_unset(value)
	}
}

fn test_computed_keyword_preserves_serialized_dom_fallback_and_css_wide_flags() {
	for keyword in [Keyword.inherit, .initial, .unset, .revert, .revert_layer,
		.currentcolor, .auto, .normal, .compact, .none_, .block] {
		text := string_from_keyword(keyword)
		for value in [dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(keyword))),
			&dom.StyleValue{css_text: ' \t${text.to_upper()}\n '}] {
			assert computed_interpolation_style_value_keyword(value)? == keyword
			assert computed_interpolation_style_value_is_inherit(value) == (keyword == .inherit)
			assert computed_interpolation_style_value_is_initial(value) == (keyword == .initial)
			assert computed_interpolation_style_value_is_unset(value) == (keyword == .unset)
			assert computed_interpolation_style_value_is_revert(value) == (keyword == .revert)
			assert computed_interpolation_style_value_is_revert_layer(value) == (keyword == .revert_layer)
			assert computed_interpolation_style_value_is_currentcolor(value) == (keyword == .currentcolor)
		}
	}
	for text in ['', ' \t\n', '12px', 'normal compact', 'not-a-keyword', 'nörmal'] {
		assert computed_interpolation_style_value_keyword(&dom.StyleValue{css_text: text}) == none
	}
}

fn test_computed_keyword_tracks_replaced_handles_and_retained_values_across_collection() {
	mut retained := []&dom.StyleValue{}
	for keyword in [Keyword.inherit, .unset, .normal, .currentcolor] {
		retained << dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(keyword)))
	}
	mut bridge := &dom.StyleValue{css_text: 'initial'}
	for index, keyword in [Keyword.inherit, .unset, .normal, .currentcolor] {
		bridge.css_value_handle = retained[index].css_value_handle
		gc_collect()
		assert computed_interpolation_style_value_keyword(bridge)? == keyword
		assert computed_interpolation_style_value_keyword(retained[index])? == keyword
	}
	bridge.css_value_handle = unsafe { nil }
	assert computed_interpolation_style_value_keyword(bridge)? == .initial
}
