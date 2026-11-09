module css

import dom

fn test_highlight_properties_inherit_computed_values_but_currentcolor_uses_each_origin() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns(dom.namespace_html_uri, 'html')!
	mut parent := document.create_element_ns(dom.namespace_html_uri, 'div')!
	mut child := document.create_element_ns(dom.namespace_html_uri, 'span')!
	parent.set_attribute_value('id', 'parent')
	parent.set_attribute_value('style', 'font-size:12px;color:lime')
	child.set_attribute_value('style', 'font-size:18px;color:red')
	mut node := document.as_node()
	node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(parent.as_node())!
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node())!
	add_document_author_style_sheet(document, '#parent::selection{color:currentcolor;background-color:green;text-shadow:green 1em 0}')
	_ = css_style_computer_for(document)
	document.update_style()
	parent_style := CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(parent, .selection))
	child_style := CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(child, .selection))
	assert parent_style.get_property_value('background-color') == 'rgb(0, 128, 0)'
	assert child_style.get_property_value('background-color') == 'rgb(0, 128, 0)'
	assert parent_style.get_property_value('color') == 'rgb(0, 255, 0)'
	assert child_style.get_property_value('color') == 'rgb(255, 0, 0)'
	assert parent_style.get_property_value('text-shadow') == child_style.get_property_value('text-shadow')
	assert child_style.get_property_value('text-shadow').contains('12px')
	parent.set_attribute_value('style', 'font-size:10px;color:lime')
	assert child_style.get_property_value('text-shadow').contains('10px')
	assert child_style.get_property_value('font-size') == '18px'
}
