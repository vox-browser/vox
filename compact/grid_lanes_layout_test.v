module main

import css
import html
import layout

fn test_grid_lanes_pack_into_shortest_track_in_both_orientations() {
	for columns in [true, false] {
		template := if columns {
			'grid-template-columns:100px 100px'
		} else {
			'grid-template-rows:100px 100px'
		}
		dimension := if columns { 'height' } else { 'width' }
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#lanes{display:grid-lanes;width:200px;height:200px;${template};fit-tolerance:0px}#first{${dimension}:100px}#second{${dimension}:20px}#third{${dimension}:30px}</style><div id="lanes"><div id="first"></div><div id="second"></div><div id="third"></div></div>')
		defer { document.finalize() }
		_ = layout.layout_document_typed_in_viewport(document, 800, 600)
		third := (document.get_element_by_id('third') or { panic('third') }).get_bounding_client_rect()
		expected_x := if columns { 100.0 } else { 20.0 }
		expected_y := if columns { 20.0 } else { 100.0 }
		assert third.x == expected_x && third.y == expected_y, '${third.x},${third.y}'
	}
}

fn test_grid_lanes_display_and_direction_grammar() {
	_ = css.parse_css_value_logic(.display, 'grid-lanes') or { panic('grid-lanes') }
	_ = css.parse_css_value_logic(.display, 'inline-grid-lanes') or { panic('inline-grid-lanes') }
	_ = css.parse_css_value_logic(.grid_lanes_direction, 'row fill-reverse track-reverse') or { panic('direction') }
	assert css.parse_css_value_logic(.grid_lanes_direction, 'normal fill-reverse') == none
	assert css.parse_css_value_logic(.grid_lanes_direction, 'row fill-reverse fill-reverse') == none
	assert css.parse_css_value_logic(.fit_tolerance, '-10px') == none
	_ = css.parse_css_value_logic(.fit_tolerance, '10%') or { panic('tolerance') }
}
