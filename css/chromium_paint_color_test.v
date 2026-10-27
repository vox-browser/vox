module css

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
