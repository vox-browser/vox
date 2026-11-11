module css

import dom

fn test_first_line_applies_font_background_and_text_effects_without_border_or_word_break() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns(dom.namespace_html_uri, 'html')!
	mut target := document.create_element_ns(dom.namespace_html_uri, 'div')!
	mut node := document.as_node()
	node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(target.as_node())!
	add_document_author_style_sheet(document, 'div::first-line{background-blend-mode:hue;font-kerning:none;font-size-adjust:0.5;text-shadow:rgb(10,20,30) 10px 20px 30px;text-underline-position:under;word-break:break-all;border:40px dotted red}')
	_ = css_style_computer_for(document)
	document.update_style()
	style := CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(target, .first_line))
	for name, expected in {'background-blend-mode':'hue', 'font-kerning':'none', 'font-size-adjust':'0.5', 'text-shadow':'rgb(10, 20, 30) 10px 20px 30px', 'text-underline-position':'under', 'word-break':'normal', 'border-top-width':'0px', 'border-top-style':'none'} {
		actual := style.get_property_value(name)
		assert actual == expected, '${name}: ${actual}'
	}
}
