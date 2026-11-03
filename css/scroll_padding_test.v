module css

import dom

fn scroll_padding_serialization(property_id PropertyID, text string) ?string {
	value := parse_css_value_logic(property_id, text) or { return none }
	return value.serialize(.normal)
}

fn test_scroll_padding_metadata_and_parsing() {
	assert number_of_longhand_properties == 364
	assert last_longhand_property_id() == .webkit_font_smoothing
	assert property_id_from_string('scroll-padding')? == .scroll_padding
	assert property_id_from_string('SCROLL-PADDING-INLINE-END')? == .scroll_padding_inline_end
	assert property_initial_value_string(.scroll_padding) == 'auto'
	assert property_initial_value_string(.scroll_padding_top) == 'auto'
	assert property_affects_layout(.scroll_padding)
	assert property_requires_computation_with_cascaded_value(.scroll_padding_left)
	assert property_accepts_type(.scroll_padding_left, .length)
	assert property_accepts_type(.scroll_padding_left, .percentage)
	assert property_accepts_length(.scroll_padding_left, Length.make_px(10))
	assert !property_accepts_length(.scroll_padding_left, Length.make_px(-10))
	assert property_accepts_percentage(.scroll_padding_left, Percentage.new(20))
	assert !property_accepts_percentage(.scroll_padding_left, Percentage.new(-20))
	assert generated_longhands_for_shorthand(.scroll_padding) == [
		PropertyID.scroll_padding_top,
		.scroll_padding_right,
		.scroll_padding_bottom,
		.scroll_padding_left,
	]
	assert generated_longhands_for_shorthand(.scroll_padding_block) == [
		PropertyID.scroll_padding_block_start,
		.scroll_padding_block_end,
	]
	assert generated_shorthands_for_longhand(.scroll_padding_inline_start) == [
		PropertyID.all,
		.scroll_padding_inline,
	]

	for property_id in [PropertyID.scroll_padding_top, .scroll_padding_right, .scroll_padding_bottom,
		.scroll_padding_left, .scroll_padding_block_start, .scroll_padding_block_end,
		.scroll_padding_inline_start, .scroll_padding_inline_end] {
		assert scroll_padding_serialization(property_id, 'auto')? == 'auto'
		assert scroll_padding_serialization(property_id, '0')? == '0px'
		assert scroll_padding_serialization(property_id, '10px')? == '10px'
		assert scroll_padding_serialization(property_id, '20%')? == '20%'
		assert scroll_padding_serialization(property_id, 'calc(10px + 5%)') != none
		for invalid in ['-10px', '-20%', 'none', '1px 2px', '1'] {
			assert scroll_padding_serialization(property_id, invalid) == none, '${property_id}: ${invalid}'
		}
	}

	assert scroll_padding_serialization(.scroll_padding, '10px')? == '10px'
	assert scroll_padding_serialization(.scroll_padding, '30px auto')? == '30px auto'
	assert scroll_padding_serialization(.scroll_padding, '1px 2px 3%')? == '1px 2px 3%'
	assert scroll_padding_serialization(.scroll_padding, '1px 2px 3% 4px')? == '1px 2px 3% 4px'
	assert scroll_padding_serialization(.scroll_padding_block, '10px 20%')? == '10px 20%'
	assert scroll_padding_serialization(.scroll_padding_inline, 'auto')? == 'auto'
	for invalid in ['-1px', 'none', '1px 2px 3px 4px 5px'] {
		assert scroll_padding_serialization(.scroll_padding, invalid) == none, invalid
	}
	assert scroll_padding_serialization(.scroll_padding_block, '1px 2px 3px') == none
}

fn test_scroll_padding_shorthand_expands_in_cssom() {
	mut declaration := CSSStyleProperties.create()
	declaration.set_property('scroll-padding', '1px 2px 3% auto', '')!
	assert declaration.get_property_value('scroll-padding') == '1px 2px 3% auto'
	assert declaration.get_property_value('scroll-padding-top') == '1px'
	assert declaration.get_property_value('scroll-padding-right') == '2px'
	assert declaration.get_property_value('scroll-padding-bottom') == '3%'
	assert declaration.get_property_value('scroll-padding-left') == 'auto'

	declaration.set_property('scroll-padding-block', '5px 6%', '')!
	assert declaration.get_property_value('scroll-padding-block-start') == '5px'
	assert declaration.get_property_value('scroll-padding-block-end') == '6%'
	declaration.set_property('scroll-padding-inline', '7px', '')!
	assert declaration.get_property_value('scroll-padding-inline-start') == '7px'
	assert declaration.get_property_value('scroll-padding-inline-end') == '7px'
}

fn test_scroll_padding_logical_properties_compute_to_physical_edges() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	element.set_attribute_value('style', 'writing-mode: vertical-rl; direction: rtl; scroll-padding-block: 7px 9px; scroll-padding-inline: 11px 13px')
	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))
	assert computed.length_percentage_to_px(.scroll_padding_top, 0)? == 13
	assert computed.length_percentage_to_px(.scroll_padding_right, 0)? == 7
	assert computed.length_percentage_to_px(.scroll_padding_bottom, 0)? == 11
	assert computed.length_percentage_to_px(.scroll_padding_left, 0)? == 9
}

fn test_scroll_padding_hook_resolves_percentages_and_calc_for_scroll_into_view() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_viewport_rect(dom.Rect{0, 0, 200, 100})
	mut html := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic(err)
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html.as_node()) or { panic(err) }
	html.set_attribute_value('style', 'scroll-padding: 10% calc(10px + 5%) auto 20%')
	computer := css_style_computer_for(document)
	computed := computer.compute_style(dom.AbstractElement.new(html, none))
	html.set_computed_properties(none, computed_properties_to_dom(computed))
	padding := document.scroll_padding_for_scrolling_box(document_node)
	assert padding.top == 10
	assert padding.right == 20
	assert padding.bottom == 0
	assert padding.left == 40
}
