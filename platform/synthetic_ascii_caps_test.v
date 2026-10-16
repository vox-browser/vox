module platform

fn test_synthetic_ascii_caps_keep_dom_lengths_and_use_isolated_uppercase_shapes() {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	plain := &Font{family: 'TestFace', source_path: source, point_size: 10, font_rendering_policy: .chromium}
	caps := &Font{ ...plain, synthesize_ascii_caps: true }
	assert !plain.has_same_identity(caps)
	assert shaping_cache_font_key(plain) != shaping_cache_font_key(caps)
	for _ in 0 .. 3 {
		for text in ['worldnews', 'abc 123', 'a\u0301', 'éאב'] {
			upper := caps.text_for_shaping(text)
			expected := shape_text(0, 0, upper, plain, .ltr)
			actual := shape_text(0, 0, text, caps, .ltr)
			assert actual.glyph_indices() == expected.glyph_indices()
			assert actual.glyph_positions() == expected.glyph_positions()
			assert actual.width() == expected.width()
			assert actual.glyphs_.map(it.length_in_code_units) == expected.glyphs_.map(it.length_in_code_units)
			assert plain.text_for_shaping(text) == text
		}
	}
	assert caps.text_for_shaping('éabcאב') == 'éABCאב'
	assert shape_text(0, 0, 'a', caps, .ltr).glyphs_[0].code_point == u32(`a`)
}
