module css

import dom

fn test_chromium_control_fonts_override_inheritance_at_ua_origin_and_refresh_after_policy_changes() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_navigable(&dom.Navigable{active_document_: document})
	mut root := document.create_element('html')!
	root.set_attribute_value('style', 'font:italic bold 20px Verdana')
	mut button := document.create_element('button')!
	mut input := document.create_element('input')!
	mut textarea := document.create_element('textarea')!
	mut author := document.create_element('button')!
	author.set_attribute_value('style', 'font:inherit')
	mut node := document.as_node()
	node.append_child(root.as_node())!
	mut parent := root.as_node()
	for element in [button, input, textarea, author] { parent.append_child(element.as_node())! }
	_ = css_style_computer_for(document)
	document.update_style()
	assert computed_value_for(button, .font_family)? == 'Verdana'
	document.set_font_rendering_policy(.chromium)
	document.update_style()
	for element in [button, input] {
		assert computed_value_for(element, .font_family)? == 'Arial'
		assert computed_value_for(element, .font_weight)? == '400'
		assert computed_value_for(element, .font_style)? == 'normal'
	}
	assert computed_value_for(textarea, .font_family)? == 'monospace'
	assert computed_value_for(author, .font_family)? == 'Verdana'
	assert computed_value_for(author, .font_weight)? == '700'
	document.set_font_rendering_policy(.libweb)
	document.update_style()
	assert computed_value_for(button, .font_family)? == 'Verdana'
}
