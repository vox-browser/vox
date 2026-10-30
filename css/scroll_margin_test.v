module css

import dom

fn scroll_margin_serialization(property_id PropertyID, text string) ?string {
	value := parse_css_value_logic(property_id, text) or { return none }
	return value.serialize(.normal)
}

fn test_scroll_margin_metadata_and_parsing() {
	assert number_of_longhand_properties == 356
	assert last_longhand_property_id() == .webkit_font_smoothing
	assert property_id_from_string('scroll-margin')? == .scroll_margin
	assert property_id_from_string('SCROLL-MARGIN-INLINE-END')? == .scroll_margin_inline_end
	assert property_initial_value_string(.scroll_margin) == '0'
	assert property_initial_value_string(.scroll_margin_top) == '0'
	assert property_affects_layout(.scroll_margin)
	assert property_requires_computation_with_cascaded_value(.scroll_margin_left)
	assert property_accepts_type(.scroll_margin_left, .length)
	assert !property_accepts_type(.scroll_margin_left, .percentage)
	assert property_accepts_length(.scroll_margin_left, Length.make_px(-10))
	assert generated_longhands_for_shorthand(.scroll_margin) == [
		PropertyID.scroll_margin_top,
		.scroll_margin_right,
		.scroll_margin_bottom,
		.scroll_margin_left,
	]
	assert generated_longhands_for_shorthand(.scroll_margin_block) == [
		PropertyID.scroll_margin_block_start,
		.scroll_margin_block_end,
	]
	assert generated_shorthands_for_longhand(.scroll_margin_inline_start) == [
		PropertyID.all,
		.scroll_margin_inline,
	]

	for property_id in [PropertyID.scroll_margin_top, .scroll_margin_right, .scroll_margin_bottom,
		.scroll_margin_left, .scroll_margin_block_start, .scroll_margin_block_end,
		.scroll_margin_inline_start, .scroll_margin_inline_end] {
		assert scroll_margin_serialization(property_id, '0')? == '0px'
		assert scroll_margin_serialization(property_id, '-10px')? == '-10px'
		assert scroll_margin_serialization(property_id, 'calc(10px - 15px)') != none
		for invalid in ['auto', '20%', '-30%', '1px 2px', '1'] {
			assert scroll_margin_serialization(property_id, invalid) == none, '${property_id}: ${invalid}'
		}
	}

	assert scroll_margin_serialization(.scroll_margin, '10px')? == '10px'
	assert scroll_margin_serialization(.scroll_margin, '30px 20px')? == '30px 20px'
	assert scroll_margin_serialization(.scroll_margin, '1px 2px 3px')? == '1px 2px 3px'
	assert scroll_margin_serialization(.scroll_margin, '-1px 2px 3px 0')? == '-1px 2px 3px 0px'
	assert scroll_margin_serialization(.scroll_margin_block, '10px 20px')? == '10px 20px'
	assert scroll_margin_serialization(.scroll_margin_inline, '-40px')? == '-40px'
	for invalid in ['auto', '20%', '1px 2px 3px 4px 5px'] {
		assert scroll_margin_serialization(.scroll_margin, invalid) == none, invalid
	}
	assert scroll_margin_serialization(.scroll_margin_block, '1px 2px 3px') == none
}

fn test_scroll_margin_shorthand_expands_in_cssom() {
	mut declaration := CSSStyleProperties.create()
	declaration.set_property('scroll-margin', '1px 2px 3px 4px', '')!
	assert declaration.get_property_value('scroll-margin') == '1px 2px 3px 4px'
	assert declaration.get_property_value('scroll-margin-top') == '1px'
	assert declaration.get_property_value('scroll-margin-right') == '2px'
	assert declaration.get_property_value('scroll-margin-bottom') == '3px'
	assert declaration.get_property_value('scroll-margin-left') == '4px'

	declaration.set_property('scroll-margin-block', '5px 6px', '')!
	assert declaration.get_property_value('scroll-margin-block-start') == '5px'
	assert declaration.get_property_value('scroll-margin-block-end') == '6px'
	declaration.set_property('scroll-margin-inline', '-7px', '')!
	assert declaration.get_property_value('scroll-margin-inline-start') == '-7px'
	assert declaration.get_property_value('scroll-margin-inline-end') == '-7px'
}

fn test_scroll_margin_logical_properties_compute_to_physical_edges() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	element.set_attribute_value('style', 'writing-mode: vertical-rl; direction: rtl; scroll-margin-block: 7px 9px; scroll-margin-inline: 11px 13px')
	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))
	assert computed.length_percentage_to_px(.scroll_margin_top, 0)? == 13
	assert computed.length_percentage_to_px(.scroll_margin_right, 0)? == 7
	assert computed.length_percentage_to_px(.scroll_margin_bottom, 0)? == 11
	assert computed.length_percentage_to_px(.scroll_margin_left, 0)? == 9
}

fn test_scroll_margin_hook_resolves_calc_for_scroll_into_view() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	element.set_attribute_value('style', 'scroll-margin: calc(10px - 15px) 2px 3px 4px')
	mut node := element.as_node()
	node.set_layout_node(&dom.LayoutNode{
		dom_node_: element.as_node()
		has_geometry_: true
		border_box_: dom.Rect{10, 200, 20, 20}
	})
	computer := css_style_computer_for(document)
	computed := computer.compute_style(dom.AbstractElement.new(element, none))
	element.set_computed_properties(none, computed_properties_to_dom(computed))
	margin := document.scroll_margin_for_element(element)
	assert margin.top == -5
	assert margin.right == 2
	assert margin.bottom == 3
	assert margin.left == 4
}
