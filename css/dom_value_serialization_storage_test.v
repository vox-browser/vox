module css

import platform

fn test_dom_keyword_serialization_needs_no_retained_or_temporary_text() {
	mut keywords := []Keyword{}
	$for member in Keyword.values {
		keywords << Keyword(member.value)
	}
	mut spellings := []string{cap: keywords.len}
	for keyword in keywords {
		value := StyleValue(KeywordStyleValue.create(keyword))
		before := platform.thread_arena_usage().used
		text := serialize_dom_style_value(value)
		$if prealloc {
			assert platform.thread_arena_usage().used == before
		}
		assert text == string_from_keyword(keyword)
		spellings << text
	}
	mut reuse := platform.begin_thread_scratch('reuse keyword serialization workspace')
	_ = []u8{len: 64 * 1024, init: 0xa5}
	reuse.finish()
	for index, keyword in keywords {
		assert spellings[index] == string_from_keyword(keyword)
	}
}

fn test_dom_value_serialization_retains_only_final_list_text() {
	mut values := []StyleValue{cap: 2048}
	for _ in 0 .. 2048 {
		values << StyleValue(StringStyleValue.create('escaped "label"'))
	}
	value := StyleValue(StyleValueList.create(values, .comma, .no))
	expected := value.serialize(.normal)
	before := platform.thread_arena_usage().used
	wrapped := dom_style_value_from_value_logic(value)
	$if prealloc {
		assert platform.thread_arena_usage().used - before < expected.len + 4096
	}
	assert wrapped.css_text == expected
	retained := typed_style_value_logic_from_dom(wrapped)?
	assert retained is StyleValueList
	assert retained.values_.len == 2048
	assert retained.values_[0].serialize(.normal) == r'"escaped \"label\""'
}

fn test_dom_value_serialization_keeps_typed_values_after_workspace_release() {
	for property, source in {
		PropertyID.content:          r'"esc\61 ped"'
		PropertyID.background_image: 'url("image.svg")'
		PropertyID.border:           '2px solid red'
		PropertyID.font:             'italic bold 14px/1.4 serif'
	} {
		value := parse_css_value_logic(property, source)?
		expected := value.serialize(.normal)
		wrapped := dom_style_value_from_value_logic(value)
		assert wrapped.css_text == expected
		retained := typed_style_value_logic_from_dom(wrapped)?
		assert retained.equals(value)
		assert retained.serialize(.normal) == expected
	}
}

fn test_dom_pending_substitution_keeps_original_shorthand_text() {
	original := parse_css_value_logic(.margin, 'var(--edges, 1px 2px)')?
	assert original is UnresolvedStyleValue
	pending := StyleValue(PendingSubstitutionStyleValue.create(original))
	wrapped := dom_style_value_from_value_logic(pending)
	assert wrapped.css_text == original.serialize(.normal)
	retained := typed_style_value_logic_from_dom(wrapped)?
	assert retained is PendingSubstitutionStyleValue
	assert retained.serialize(.normal) == ''
	assert retained.original_shorthand_value_ref().serialize(.normal) == wrapped.css_text
}
