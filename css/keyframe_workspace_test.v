module css

import dom

fn keyframe_workspace_value(property_id PropertyID, text string) &dom.StyleValue {
	return parse_css_value(ParsingParams{}, text, property_id) or { panic(text) }
}

fn test_native_keyframe_lookup_tables_do_not_accumulate_with_returned_values() {
	mut document := dom.Document.create(dom.url_about_blank())
	element := document.create_element('div')!
	subject := dom.AbstractElement.new(element, none)
	mut computer := StyleComputer.new(document)
	base := computed_properties_with_initial_values()
	frame := ResolvedKeyFrame{
		properties: {PropertyID.opacity: keyframe_workspace_value(.opacity, '0.25')}
	}
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	defer {
		allocations.finish()
		document.finalize()
		document.release_native_storage()
	}
	for _ in 0 .. 8 { _ = computer.compute_keyframe_values(subject, frame, base) }
	mut before := i64(0)
	$if prealloc { before = document.native_storage().arena.usage().used }
	mut last := map[PropertyID]&dom.StyleValue{}
	for _ in 0 .. 64 { last = computer.compute_keyframe_values(subject, frame, base) }
	$if prealloc {
		growth := document.native_storage().arena.usage().used - before
		assert growth < 64 * 1024, '${growth} bytes retained for keyframe lookup and returned values'
	}
	value := last[.opacity] or { panic('missing opacity') }
	assert computed_interpolation_number_from_dom_style_value(value)? == 0.25
}

fn test_native_keyframe_values_survive_lookup_retirement_and_keep_substitution_and_fallback() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_viewport_rect(dom.Rect{width: 400, height: 300})
	mut element := document.create_element('div')!
	element.set_attribute_value('style', '--gap:4px;height:5px;direction:rtl')
	subject := dom.AbstractElement.new(element, none)
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	defer {
		allocations.finish()
		document.finalize()
		document.release_native_storage()
	}
	mut computer := StyleComputer.new(document)
	base := computer.compute_style(subject)
	element.set_computed_properties(none, computed_properties_to_dom(base))
	frame := ResolvedKeyFrame{
		properties: {
			PropertyID.width: keyframe_workspace_value(.width, 'calc(var(--gap) + 6px)')
			.margin_inline_start: keyframe_workspace_value(.margin_inline_start, '8px')
		}
		use_initial_properties: {PropertyID.height: true}
	}
	values := computer.compute_keyframe_values(subject, frame, base)
	for _ in 0 .. 32 { _ = computer.compute_keyframe_values(subject, frame, base) }
	gc_collect()
	context := LengthResolutionContext.for_element(&subject)
	width := values[.width] or { panic('width') }
	height := values[.height] or { panic('height') }
	margin := values[.margin_right] or { panic('physical margin') }
	assert LengthPercentage.from_style_value(width).to_px(context, CSSPixels.new(400)).to_double() == 10
	assert LengthPercentage.from_style_value(height).to_px(context, CSSPixels.new(300)).to_double() == 5
	assert LengthPercentage.from_style_value(margin).to_px(context, CSSPixels.new(400)).to_double() == 8
	assert (frame.properties[.width] or { panic('specified width') }).css_text.contains('var(')
}
