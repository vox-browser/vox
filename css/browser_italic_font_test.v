module css

import dom

fn test_browser_font_style_survives_cascade_copy_and_visibility_changes() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	mut computer := FontComputer.create_for_document(document)
	regular := computer.compute_font_for_style_values(['serif'], CSSPixels.new(16), 0, 400,
		Percentage.new(100), .auto_, map[string]f64{}, FontFeatureData{})
	for slope in [1, 2] {
		italic := computer.compute_font_for_style_values(['serif'], CSSPixels.new(16), slope, 400,
			Percentage.new(100), .auto_, map[string]f64{}, FontFeatureData{})
		assert italic != regular
		assert !regular.fonts[0].font.font_for_rendering().italic
		assert italic.fonts[0].font.font_for_rendering().italic
		assert italic.last_resort_font.font_for_rendering().italic
		mut copy := FontCascadeList.create()
		copy.extend(italic)
		assert copy.fonts[0].font.font_for_rendering().italic
		invisible := italic.font_with_visibility(&italic.fonts[0].font, true)
		assert invisible.font_for_rendering().italic && invisible.font_for_rendering().is_invisible
		mut changed := owned_platform_font(&italic.fonts[0].font)
		held := changed.font_for_rendering()
		changed.italic = false
		assert !changed.font_for_rendering().italic
		assert held.italic
	}
}
