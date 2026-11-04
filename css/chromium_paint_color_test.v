module css

import dom

fn test_computed_hsl_colors_retain_their_alpha_without_changing_rgb_syntax() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := document.create_element('html')!
	context := ComputationContext{ abstract_element: dom.AbstractElement.new(root, none) }
	for text in ['hsla(0, 0%, 13.3333333333%, .85)', 'hsl(0 0% 13.3333333333% / .85)'] {
		parsed := parse_css_value_logic(.color, text) or { panic(text) }
		value := parsed.absolutized(context)
		assert value is RGBColorStyleValue
		assert value.color_syntax() == .legacy
		components := value.srgb_paint_components() or { panic(text) }
		assert components[3] == 0.85
		recomputed := StyleValue(value.absolutized(context))
		again := recomputed.srgb_paint_components() or { panic(text) }
		assert again[3] == 0.85
	}
}

fn test_chromium_rgb_paint_colors_quantize_only_legacy_alpha() {
	for index, text in [
		'rgba(10.5, 20.25, 30.75, .25)',
		'rgba(10.5, 20.25, 30.75, 25%)',
		'rgb(10.5 20.25 30.75 / .25)',
		'rgb(10.5 20.25 30.75 / 25%)',
	] {
		value := parse_css_value_logic(.color, text) or { panic(text) }
		components := value.srgb_paint_components() or { panic('RGB components') }
		assert components[0] == 10.5 / 255
		assert components[1] == 20.25 / 255
		assert components[2] == 30.75 / 255
		assert components[3] == if index < 2 { 64.0 / 255 } else { 0.25 }
	}
}
