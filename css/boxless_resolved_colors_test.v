module css

import dom

fn test_cssom_resolves_currentcolor_without_a_layout_box() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut element := document.create_element_ns(dom.namespace_html_uri, 'html')!
	mut node := document.as_node()
	node.append_child(element.as_node())!
	element.set_attribute_value('style', 'display:none;color:lime;background-color:currentcolor;text-decoration-color:currentcolor')
	add_document_author_style_sheet(document, 'html::selection{color:lime;background-color:currentcolor}')
	_ = css_style_computer_for(document)
	document.update_style()
	for target in [dom.AbstractElement.new(element, none), dom.AbstractElement.new(element, .selection)] {
		style := CSSStyleProperties.create_resolved_style(target)
		assert style.get_property_value('color') == 'rgb(0, 255, 0)'
		assert style.get_property_value('background-color') == 'rgb(0, 255, 0)'
	}
}
