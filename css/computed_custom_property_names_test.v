module css

import dom

fn test_computed_property_names_include_live_inherited_and_registered_custom_properties() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	document.set_navigable(&dom.Navigable{active_document_: document})
	mut parent := document.create_element_ns(dom.namespace_html_uri, 'html')!
	mut target := document.create_element_ns(dom.namespace_html_uri, 'div')!
	mut root := unsafe { &dom.Node(document) }
	root.append_child(parent.as_node())!
	mut parent_node := parent.as_node()
	parent_node.append_child(target.as_node())!
	parent.set_attribute_value('style', '--inherited: parent;--blocked: private')
	target.set_attribute_value('style', '--own: child;--invalid:var(--missing)')
	add_document_author_style_sheet(document, '@property --initial{syntax:"<length>";inherits:false;initial-value:10px}@property --blocked{syntax:"*";inherits:false}@property --absent{syntax:"*";inherits:true}')
	_ = css_style_computer_for(document)
	document.update_style()
	declaration := CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(target, none))
	names := declaration.property_names()
	assert '--inherited' in names && '--own' in names && '--initial' in names
	assert '--blocked' !in names && '--absent' !in names && '--invalid' !in names
	assert names.len == number_of_longhand_properties + 3
	assert declaration.item(uint(number_of_longhand_properties)) == '--inherited'
	assert declaration.get_property_value('--initial') == '10px'
	target.set_attribute_value('style', '--changed: fresh')
	assert '--changed' in declaration.property_names()
	assert '--own' !in declaration.property_names()
}
