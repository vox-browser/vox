module css

import dom
import platform

fn coordinating_query_style(images string, clips string, typed bool) &ComputedProperties {
	mut style := computed_properties_with_initial_values()
	for property, text in {PropertyID.background_image:images, .background_clip:clips} {
		value := if typed {
			parse_css_value(ParsingParams{}, text, property) or { panic('invalid fixture ${text}') }
		} else { &dom.StyleValue{css_text:text} }
		style.set_property(property, value, .no, .no)
	}
	return style
}

fn test_background_color_uses_the_last_coordinated_clip_including_none_images() {
	for typed in [false, true] {
		for count, expected in {1:BackgroundBox.border_box, 2:.padding_box, 3:.content_box, 4:.border_box} {
			images := []string{len:count, init:'none'}.join(', ')
			style := coordinating_query_style(images, 'border-box, padding-box, content-box', typed)
			assert style.background_color_clip() == expected
			assert style.background_layers().len == 0
		}
		style := coordinating_query_style('linear-gradient(red, blue), url("a,b.png")', 'padding-box, content-box', typed)
		assert style.background_color_clip() == .content_box
		assert style.background_layers().len == 2
	}
}

fn test_typed_background_scalar_queries_do_not_mint_item_wrappers() {
	style := computed_properties_with_initial_values()
	assert style.background_layers().len == 0
	assert style.background_color_clip() == .border_box
	before := platform.thread_arena_usage().used
	for _ in 0 .. 128 {
		assert style.background_layers().len == 0
		assert style.background_color_clip() == .border_box
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
}

fn test_direct_coordinating_queries_keep_noncomma_and_unresolved_values_on_the_original_path() {
	space := dom_style_value_from_value_logic(StyleValue(StyleValueList.create([
		StyleValue(KeywordStyleValue.create(.none_)), StyleValue(KeywordStyleValue.create(.none_)),
	], .space, .yes)))
	assert !computed_coordinating_value_is_none(space)
	assert typed_coordinating_value_count(space) == none
	assert typed_coordinating_keyword_at(space, 0) == none
	assert typed_coordinating_value_count(&dom.StyleValue{css_text:'none, none'}) == none
	unresolved := parse_css_value(ParsingParams{}, 'var(--images)', .background_image) or { panic('unresolved image') }
	assert typed_coordinating_value_count(unresolved) == none
	quoted := dom_style_value_from_value_logic(StyleValue(StringStyleValue.create('none')))
	assert !computed_coordinating_value_is_none(quoted)
}
