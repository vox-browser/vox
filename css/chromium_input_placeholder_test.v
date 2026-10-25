module css

import dom

fn test_chromium_input_placeholder_resets_inherited_line_height_but_textarea_keeps_it() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_navigable(&dom.Navigable{ active_document_: document })
	mut root := document.create_element('html')!
	mut document_node := document.as_node()
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	mut hosts := []&dom.Element{}
	mut placeholders := []&dom.Element{}
	for tag in ['input', 'textarea'] {
		mut host := document.create_element(tag)!
		host.set_attribute_value('style', 'font:14px/48px Arial')
		root_node.append_child(host.as_node())!
		shadow := host.attach_a_user_agent_shadow_root(.named)
		mut placeholder := document.create_element('div')!
		mut shadow_node := unsafe { &dom.Node(shadow) }
		shadow_node.append_child(placeholder.as_node())!
		placeholder.set_associated_shadow_host_pseudo_element(int(PseudoElement.placeholder))
		hosts << host
		placeholders << placeholder
	}
	add_document_author_style_sheet(document,
		'input::placeholder, textarea::placeholder { line-height:80px !important; color:red }')
	mut computer := css_style_computer_for(document)
	for policy in [dom.FontRenderingPolicy.libweb, .chromium, .libweb] {
		document.set_font_rendering_policy(policy)
		document.update_style()
		for index, placeholder in placeholders {
			expected := if policy == .chromium && index == 0 { 'normal' } else { '48px' }
			direct := computer.compute_style(dom.AbstractElement.new(hosts[index], dom.PseudoElement.placeholder))
			assert direct.property(.line_height, .no)?.css_text == expected
			assert computed_value_for(placeholder, .line_height)? == expected
			style := up_to_date_computed_properties_for_element(placeholder)
			if policy == .chromium && index == 0 {
				assert style.is_property_important(.line_height)
				assert !style.is_property_inherited(.line_height)
			}
			assert computed_value_for(hosts[index], .line_height)? == '48px'
			assert computed_value_for(placeholder, .color)? == 'rgb(255, 0, 0)'
		}
	}
}
