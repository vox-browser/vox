module css

import dom

fn test_each_highlight_pseudo_keeps_its_own_cascade_target() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut element := document.create_element_ns(dom.namespace_html_uri, 'html')!
	mut node := document.as_node()
	node.append_child(element.as_node())!
	add_document_author_style_sheet(document, 'html::selection{background-color:blue}html::target-text{background-color:red}html::spelling-error{background-color:lime}html::grammar-error{background-color:green}html::search-text{background-color:yellow}')
	_ = css_style_computer_for(document)
	document.update_style()
	for index, pseudo in [dom.PseudoElement.selection, .target_text, .spelling_error, .grammar_error, .search_text] {
		style := CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(element, pseudo))
		expected := ['rgb(0, 0, 255)', 'rgb(255, 0, 0)', 'rgb(0, 255, 0)', 'rgb(0, 128, 0)', 'rgb(255, 255, 0)'][index]
		assert style.get_property_value('background-color') == expected, '${pseudo}: ${style.get_property_value('background-color')}'
	}
}
