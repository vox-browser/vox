module css

import dom

fn browser_font_policy_style(element &dom.Element, pseudo ?dom.PseudoElement) &ComputedProperties {
	bridge := dom.AbstractElement.new(element, pseudo).computed_properties() or { panic('missing style') }
	return computed_properties_from_dom(bridge) or { panic('missing style owner') }
}

fn test_browser_font_keyword_policy_preserves_libweb_defaults_and_chromium_tables() {
	mut document := dom.Document.create(dom.url_about_blank())
	assert absolute_size_mapping_for_document(.x_small, CSSPixels.new(16), document) == CSSPixels.new(12)
	assert absolute_size_mapping_for_document(.small, CSSPixels.new(16), document) == StyleComputer.absolute_size_mapping(.small, CSSPixels.new(16))
	document.set_font_size_keyword_policy(.chromium)
	for index, size in [AbsoluteSize.xx_small, .x_small, .small, .medium, .large, .x_large, .xx_large, .xxx_large] {
		assert absolute_size_mapping_for_document(size, CSSPixels.new(16), document) == CSSPixels.new([9, 10, 13, 16, 18, 24, 32, 48][index])
	}
	assert absolute_size_mapping_for_document(.x_small, CSSPixels.new(13), document) == CSSPixels.new(10)
	document.set_quirks_mode(.yes)
	assert absolute_size_mapping_for_document(.x_small, CSSPixels.new(13), document) == CSSPixels.new(9)
	document.set_font_size_keyword_policy(.libweb)
	assert absolute_size_mapping_for_document(.x_small, CSSPixels.new(16), document) == CSSPixels.new(12)
}

fn test_browser_font_keyword_policy_recomputes_root_inherited_relative_and_pseudo_styles() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_navigable(&dom.Navigable{active_document_: document})
	mut root := document.create_element_ns(dom.namespace_html_uri, 'html')!
	root.set_attribute_value('style', 'font-size:x-small')
	mut child := document.create_element_ns(dom.namespace_html_uri, 'div')!
	child.set_attribute_value('id', 'child')
	child.set_attribute_value('style', 'font-size:120%')
	mut document_node := document.as_node()
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(child.as_node())!
	_ = css_style_computer_for(document)
	add_document_author_style_sheet(document, '#child::before{content:"label";font-size:small}')
	document.update_style()
	assert browser_font_policy_style(root, none).font_size() == CSSPixels.new(12)
	version := document.style_environment_version()
	document.set_font_size_keyword_policy(.chromium)
	assert document.style_environment_version() == version + 1
	document.update_style()
	assert browser_font_policy_style(root, none).font_size() == CSSPixels.new(10)
	assert browser_font_policy_style(child, none).font_size() == CSSPixels.new(12)
	assert browser_font_policy_style(child, .before).font_size() == CSSPixels.new(13)
	document.set_font_size_keyword_policy(.libweb)
	document.update_style()
	assert browser_font_policy_style(root, none).font_size() == CSSPixels.new(12)
}
