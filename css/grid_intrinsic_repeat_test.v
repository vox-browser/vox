module css

fn test_auto_repeat_accepts_intrinsic_tracks_without_unbounded_flex_tracks() {
	for property in [PropertyID.grid_template_columns, .grid_template_rows] {
		for value in ['repeat(auto-fill, auto)', 'repeat(auto-fit, min-content)',
			'repeat(auto-fill, max-content)', 'repeat(auto-fill, fit-content(40px))',
			'repeat(auto-fill, minmax(auto, max-content))', 'repeat(auto-fit, minmax(20px, 1fr))'] {
			parsed := parse_css_value_logic(property, value) or { panic('rejected ${value}') }
			assert parsed.serialize(.normal) == value
		}
		for value in ['repeat(auto-fill, 1fr)', 'repeat(auto-fit, minmax(auto, 1fr))',
			'repeat(auto-fill, minmax(1fr, auto))'] {
			assert parse_css_value_logic(property, value) == none, 'accepted ${value}'
		}
	}
}
