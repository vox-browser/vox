module css

import dom

fn test_idle_computation_trim_preserves_active_inputs_and_computed_values() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut scope := document.enter_native_storage()
	mut element := document.create_element_ns(dom.namespace_html_uri, 'div')!
	element.set_attribute_value('style', 'color:red;width:17px;font-size:16px')
	mut computer := css_style_computer_for(document)
	style := computer.compute_style(dom.AbstractElement.new(element, none))
	color := style.property(.color, .no)?.css_text
	mut fonts := computer.font_computer_
	mut inputs := fonts.acquire_font_input_scratch()
	payload := []u8{len:128 * 1024, init:67}
	trim_unused_computation_pages(document)
	assert payload[0] == 67 && payload[payload.len - 1] == 67
	inputs.finish()
	trim_unused_computation_pages(document)
	assert style.property(.width, .no)?.css_text == '17px'
	assert style.property(.color, .no)?.css_text == color
	mut again := fonts.acquire_font_input_scratch()
	replacement := []u8{len:128 * 1024, init:41}
	assert replacement[0] == 41 && replacement[replacement.len - 1] == 41
	again.finish()
	assert style.property(.width, .no)?.css_text == '17px'
	scope.finish()
	document.finalize()
	document.release_native_storage()
}
