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
