module css

fn test_font_shorthand_accepts_normal_line_height_and_oblique_without_angle() {
	for text in ['normal medium/normal sans-serif', '16px/normal serif', 'oblique 16px simple',
		'bolder oblique 16px simple', 'oblique 10deg 16px a', 'normal oblique normal 900 medium/normal Menu'] {
		assert parse_css_value(ParsingParams{}, text, .font) != none, text
	}
	for text in ['oblique 100deg 16px a', '16px/normal', 'normal normal normal normal normal 16px a'] {
		assert parse_css_value(ParsingParams{}, text, .font) == none, text
	}
	assert parse_css_value(ParsingParams{}, 'normal', .line_height) != none
	assert parse_css_value(ParsingParams{}, 'normal 1', .line_height) == none
	assert parse_css_value(ParsingParams{}, 'oblique', .font_style) != none
	assert parse_css_value(ParsingParams{}, 'oblique 16px', .font_style) == none
}
