module css

import dom

fn test_mathml_anchor_matches_link_selectors_only_with_href() {
	document := dom.Document.create(dom.url_about_blank())
	mut anchor := document.create_element_ns('http://www.w3.org/1998/Math/MathML', 'a')!
	assert !element_matches_selector(anchor, ':link')
	anchor.set_attribute_value('href', 'https://example.test/')
	assert element_matches_selector(anchor, ':link')
	assert element_matches_selector(anchor, ':any-link')
	assert !element_matches_selector(anchor, ':visited')
	anchor.remove_attribute('href')
	assert !element_matches_selector(anchor, ':any-link')
	mut text := document.create_element_ns('http://www.w3.org/1998/Math/MathML', 'mtext')!
	text.set_attribute_value('href', 'https://example.test/')
	assert !element_matches_selector(text, ':any-link')
}

fn test_mathml_link_uses_link_color_without_underline() {
	document := dom.Document.create(dom.url_about_blank())
	mut anchor := document.create_element_ns('http://www.w3.org/1998/Math/MathML', 'a')!
	anchor.set_attribute_value('href', 'https://example.test/')
	style := StyleComputer.new(document).compute_style(dom.AbstractElement.new(anchor, none))
	assert style.text_decoration_line().len == 0
	mut html_anchor := document.create_element_ns('http://www.w3.org/1999/xhtml', 'a')!
	html_anchor.set_attribute_value('href', 'https://example.test/')
	html_style := StyleComputer.new(document).compute_style(dom.AbstractElement.new(html_anchor, none))
	assert html_style.text_decoration_line().len > 0
	assert style.property(.color, .no)?.css_text == html_style.property(.color, .no)?.css_text
}
