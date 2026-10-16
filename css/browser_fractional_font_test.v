module css

import dom
import math

fn test_browser_font_sizes_keep_fractional_px_through_inheritance_percentages_and_em() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_navigable(&dom.Navigable{active_document_: document})
	mut root := document.create_element('html')!
	root.set_attribute_value('style', 'font-size:14.4px')
	mut child := document.create_element('div')!
	child.set_attribute_value('style', 'font-size:150%')
	mut grandchild := document.create_element('div')!
	grandchild.set_attribute_value('style', 'font-size:1.2345em')
	mut document_node := document.as_node()
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(child.as_node())!
	mut child_node := child.as_node()
	child_node.append_child(grandchild.as_node())!
	mut computer := css_style_computer_for(document)
	document.update_style()
	for index, element in [root, child, grandchild] {
		bridge := dom.AbstractElement.new(element, none).computed_properties() or { panic('missing style') }
		mut style := computed_properties_from_dom(bridge) or { panic('missing style owner') }
		expected := [14.4, 21.6, 26.6652][index]
		assert math.abs(style.resolved_font_size_px() - expected) < 0.0000001
		font := style.first_available_computed_font(computer.font_computer()).font_for_rendering()
		assert math.abs(f64(font.point_size) - [14.4, 21.6, 26.66][index]) < 0.000002
	}
}

fn test_fractional_font_sizes_with_the_same_csspixel_value_have_distinct_cascades() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	mut computer := FontComputer.create_for_document(document)
	assert CSSPixels.nearest_value_for(14.409) == CSSPixels.nearest_value_for(14.411)
	first := computer.compute_font_for_style_values_at_size(['serif'], 14.409, 0, 400,
		Percentage.new(100), .auto_, map[string]f64{}, FontFeatureData{})
	second := computer.compute_font_for_style_values_at_size(['serif'], 14.411, 0, 400,
		Percentage.new(100), .auto_, map[string]f64{}, FontFeatureData{})
	assert first != second
	assert first.fonts[0].font.font_for_rendering().point_size != second.fonts[0].font.font_for_rendering().point_size
}
