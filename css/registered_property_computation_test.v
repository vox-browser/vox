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

fn test_registered_values_compute_calculations_and_canonical_units() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	mut element := document.create_element_ns(dom.namespace_html_uri, 'html')!
	mut node := document.as_node()
	node.append_child(element.as_node())!
	for index, definition in [
		['<length>', 'calc(10px + 20px)', '30px'],
		['<integer>', 'calc(2.6)', '3'],
		['<number>', 'calc(24 / 10)', '2.4'],
		['<integer>+', '15 calc(2.4) calc(2.6)', '15 2 3'],
		['<angle>', '400grad', '360deg'],
		['<angle>', 'calc(360deg + 400grad)', '720deg'],
		['<time>', '1000ms', '1s'],
		['<time>', 'calc(1s + 1000ms)', '2s'],
		['<resolution>', '96dpi', '1dppx'],
		['<resolution>', 'calc(1dppx + 96dpi)', '2dppx'],
		['<length-percentage>', 'calc(10px + 10%)', 'calc(10% + 10px)'],
	] {
		name := '--computed-${index}'
		register_property_for_document(mut document, PropertyDefinition{name:name, syntax:definition[0], inherits:false, initial_value:definition[1]})!
	}
	_ = css_style_computer_for(document)
	document.update_style()
	style := CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(element, none))
	for index, expected in ['30px', '3', '2.4', '15 2 3', '360deg', '720deg', '1s', '2s', '1dppx', '2dppx', 'calc(10% + 10px)'] {
		assert style.get_property_value('--computed-${index}') == expected
	}
}
