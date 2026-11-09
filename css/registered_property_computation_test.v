module css

import dom

fn test_registered_custom_properties_compute_relative_units_before_inheritance() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	mut parent := document.create_element_ns(dom.namespace_html_uri, 'html')!
	mut child := document.create_element_ns(dom.namespace_html_uri, 'div')!
	mut node := unsafe { &dom.Node(document) }
	node.append_child(parent.as_node())!
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node())!
	parent.set_attribute_value('style', 'font-size:10px;line-height:20px;color:blue;--distance:14em;--rows:10lh;--tone:currentcolor;--plain:14em')
	child.set_attribute_value('style', 'font-size:20px;line-height:30px;color:red;--alias:var(--distance)')
	for definition in [PropertyDefinition{name:'--distance',syntax:'<length>',inherits:true,initial_value:'0px'},
		PropertyDefinition{name:'--rows',syntax:'<length>',inherits:true,initial_value:'0px'},
		PropertyDefinition{name:'--tone',syntax:'<color>',inherits:true,initial_value:'black'},
		PropertyDefinition{name:'--alias',syntax:'<length>',inherits:true,initial_value:'0px'}] {
		register_property_for_document(mut document, definition)!
	}
	_ = css_style_computer_for(document)
	document.update_style()
	parent_style := CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(parent, none))
	child_style := CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(child, none))
	assert parent_style.get_property_value('--distance') == '140px'
	assert parent_style.get_property_value('--rows') == '200px'
	assert parent_style.get_property_value('--tone') == 'rgb(0, 0, 255)'
	assert parent_style.get_property_value('--plain') == '14em'
	assert child_style.get_property_value('--distance') == '140px'
	assert child_style.get_property_value('--alias') == '140px'
	assert child_style.get_property_value('--tone') == 'rgb(0, 0, 255)'
}
