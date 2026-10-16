module css

import dom

fn test_document_shaping_policy_rebuilds_fonts_and_preserves_held_cascades() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut computer := FontComputer.create_for_document(document)
	coarse := computer.compute_font_for_style_values(['serif'], CSSPixels.new(16), 0, 400,
		Percentage.new(100), .auto_, map[string]f64{}, FontFeatureData{})
	assert coarse.fonts.len > 0
	for entry in coarse.fonts { assert entry.font.font_for_rendering().font_rendering_policy == .libweb }
	version := document.style_environment_version()
	document.set_font_rendering_policy(.chromium)
	assert document.style_environment_version() == version + 1
	precise := computer.compute_font_for_style_values(['serif'], CSSPixels.new(16), 0, 400,
		Percentage.new(100), .auto_, map[string]f64{}, FontFeatureData{})
	assert precise != coarse
	for entry in precise.fonts { assert entry.font.font_for_rendering().font_rendering_policy == .chromium }
	assert precise.last_resort_font.font_for_rendering().font_rendering_policy == .chromium
	for entry in coarse.fonts { assert entry.font.font_for_rendering().font_rendering_policy == .libweb }
	invisible := precise.font_with_visibility(&precise.fonts[0].font, true)
	assert invisible.font_for_rendering().font_rendering_policy == .chromium
	document.set_font_rendering_policy(.libweb)
	assert computer.compute_font_for_style_values(['serif'], CSSPixels.new(16), 0, 400,
		Percentage.new(100), .auto_, map[string]f64{}, FontFeatureData{}) == coarse
}

fn test_policy_changes_refresh_an_elements_cached_font_without_changing_its_css() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_navigable(&dom.Navigable{active_document_: document})
	mut root := document.create_element('html')!
	root.set_attribute_value('style', 'font:16px Arial')
	mut node := document.as_node()
	node.append_child(root.as_node())!
	computer := css_style_computer_for(document)
	for policy in [dom.FontRenderingPolicy.libweb, .chromium, .libweb] {
		document.set_font_rendering_policy(policy)
		document.update_style()
		mut style := unsafe { &ComputedProperties(up_to_date_computed_properties_for_element(root)) }
		font := style.first_available_computed_font(computer.font_computer())
		assert font.font_for_rendering().font_rendering_policy.str() == policy.str()
	}
}
