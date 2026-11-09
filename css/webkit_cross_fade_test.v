module css

fn test_cross_fade_resolves_nested_image_schemes_and_preserves_image_set_constraints() {
	source := '-webkit-cross-fade(light-dark(url(a),url(b)),light-dark(url(c),url(d)),50%)'
	value := parse_css_value_logic(.background_image,source) or { panic(source) }
	computed := value.absolutized(ComputationContext{color_scheme:PreferredColorScheme.dark}).serialize(.resolved_value)
	assert computed == '-webkit-cross-fade(url("b"), url("d"), 0.5)'
	assert parse_css_value_logic(.background_image,'image-set(${source} 1x)') != none
	assert parse_css_value_logic(.background_image,'image-set(-webkit-cross-fade(image-set(url(a) 1x),url(b),0.5) 1x)') == none
	for invalid in ['-webkit-cross-fade(red,url(b),0.5)','-webkit-cross-fade(url(a),url(b))','-webkit-cross-fade(url(a),url(b),5px)'] {
		assert parse_css_value_logic(.background_image,invalid) == none,invalid
	}
}
