module css

import dom

fn test_resolved_generated_content_preserves_absent_empty_and_nonempty_alternatives() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element_ns(dom.namespace_html_uri, 'div')!
	target := dom.AbstractElement.new(element, .before)
	for source, expected in {'"visual"':false, '"visual" / ""':true, '"visual" / "spoken"':true} {
		mut style := computed_properties_with_initial_values()
		value := parse_css_value_logic(.content, source) or { panic('bad fixture') }
		style.set_property(.content, dom_style_value_from_value_logic(value), .no, .no)
		content := style.content(&target, 0, map[string]CounterStyle{}).content_data
		assert content.has_alt_text == expected
		assert content.text == 'visual'
		assert content.alt_text == if source.ends_with('"spoken"') { 'spoken' } else { '' }
		style.set_content(content)
		assert style.computed_content()?.has_alt_text == expected
	}
}
