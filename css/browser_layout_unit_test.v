module css

import dom

fn test_browser_box_lengths_truncate_positive_and_negative_fractions_after_font_unit_resolution() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_navigable(&dom.Navigable{active_document_: document})
	document.set_font_rendering_policy(.chromium)
	mut root := document.create_element('html')!
	root.set_attribute_value('style', 'font:16px Arial;margin-left:0.4em;margin-right:-0.4em;padding-left:6.4px')
	mut node := document.as_node()
	node.append_child(root.as_node())!
	_ = css_style_computer_for(document)
	document.update_style()
	style := up_to_date_computed_properties_for_element(root)
	assert style.length_percentage_to_px(.margin_left, 100)? == 6.390625
	assert style.length_percentage_to_px(.margin_right, 100)? == -6.390625
	assert style.length_percentage_to_px(.padding_left, 100)? == 6.390625
	document.set_font_rendering_policy(.libweb)
	document.update_style()
	default_style := up_to_date_computed_properties_for_element(root)
	assert default_style.length_percentage_to_px(.margin_left, 100)? == 6.40625
	assert default_style.length_percentage_to_px(.margin_right, 100)? == -6.40625
}
