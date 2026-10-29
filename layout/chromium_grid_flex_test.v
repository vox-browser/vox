module layout

import html

fn test_chromium_grid_flex_preserves_float_factor_subtraction_when_freezing() {
	mut tracks := [GridTrack{ flex: 1.65 },
		GridTrack{ flex: 1, base_size: CSSPixels.nearest_value_for(542.8125) }]
	chromium_expand_flexible_grid_tracks(mut tracks, CSSPixels.new(1098), CSSPixels.new(42))
	assert tracks[0].base_size.to_double() == 513.171875
	assert tracks[1].base_size.to_double() == 542.8125
	mut upstream := [GridTrack{ flex: 1.65 },
		GridTrack{ flex: 1, base_size: CSSPixels.nearest_value_for(542.8125) }]
	expand_flexible_grid_tracks(mut upstream, CSSPixels.new(1098), CSSPixels.new(42))
	assert upstream[0].base_size.to_double() == 513.1875
}

fn test_chromium_grid_flex_carries_fractional_layout_units_to_later_tracks() {
	mut tracks := [GridTrack{ flex: 1 }, GridTrack{ flex: 2 }, GridTrack{ flex: 3 }]
	chromium_expand_flexible_grid_tracks(mut tracks, CSSPixels.new(100), CSSPixels.new(0))
	assert tracks.map(it.base_size.to_double()) == [16.65625, 33.34375, 50.0]
	mut partial := [GridTrack{ flex: .2 }, GridTrack{ flex: .3 }]
	chromium_expand_flexible_grid_tracks(mut partial, CSSPixels.new(100), CSSPixels.new(0))
	assert partial.map(it.base_size.to_double()) == [20.0, 30.0]
}

fn test_chromium_grid_flex_uses_the_same_rounding_for_columns_and_rows() {
	for axis in ['columns', 'rows'] {
		minimum := if axis == 'columns' { 'width' } else { 'height' }
		mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#grid{display:grid;${minimum}:1098px;gap:42px;grid-template-${axis}:1.65fr 1fr}#second{min-${minimum}:542.8125px}</style><div id="grid"><i></i><i id="second"></i></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 1280, 1280)
		grid := document.get_element_by_id('grid') or { panic('missing grid') }
		node := grid.as_node().layout_node() or { panic('missing grid layout') }
		data := node.used_grid_data()
		actual := if axis == 'columns' { data.columns } else { data.rows }
		assert actual == [513.171875, 542.8125]
	}
}
