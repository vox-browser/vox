module css

import dom

fn test_color_swatch_aliases_match_and_preserve_serialization() {
	document := dom.Document.create(dom.url_about_blank())
	mut input := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input')!
	input.set_attribute_value('type', 'color')
	for name in ['color-swatch', '-moz-color-swatch', '-webkit-color-swatch'] {
		text := 'input::${name}'
		selectors := parse_selector_with_parser(text, map[string]bool{}) or { panic(text) }
		selector := selectors.selectors[0]
		assert selector.serialize() == text
		assert selector.pseudo_element()?.type_ == .color_swatch
		mut context := MatchContext{}
		assert matches(selector, input, none, mut context, .color_swatch, none, .normal, none)
		mut wrong_context := MatchContext{}
		assert !matches(selector, input, none, mut wrong_context, .webkit_color_swatch_wrapper, none, .normal, none)
	}
}

fn test_color_swatch_default_geometry_and_author_overrides() {
	document := dom.Document.create(dom.url_about_blank())
	mut input := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input')!
	input.set_attribute_value('type', 'color')
	computer := StyleComputer.new(document)
	wrapper_target := dom.AbstractElement.new(input, dom.PseudoElement.webkit_color_swatch_wrapper)
	swatch_target := dom.AbstractElement.new(input, dom.PseudoElement.color_swatch)
	wrapper := computer.compute_style(wrapper_target)
	swatch := computer.compute_style(swatch_target)
	assert wrapper.display().is_flex_inside()
	assert (wrapper.property(.padding_top, .no) or { panic('padding') }).css_text == '4px'
	assert (swatch.property(.flex_grow, .no) or { panic('flex') }).css_text == '1'
	add_document_author_style_sheet(document, 'input::-webkit-color-swatch-wrapper { padding: 9px; } input::-webkit-color-swatch { border: 4px solid blue; }')
	styled_wrapper := computer.compute_style(wrapper_target)
	styled_swatch := computer.compute_style(swatch_target)
	assert (styled_wrapper.property(.padding_top, .no) or { panic('padding') }).css_text == '9px'
	assert (styled_swatch.property(.border_top_width, .no) or { panic('border') }).css_text == '4px'
}
