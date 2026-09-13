module svg

import math

fn test_parse_all_path_commands_and_serialize() {
	path :=
		parse_path_data('M1 2 3 4 l5,-6 H9 v2 C1 2 3 4 5 6 s7 8 9 10 Q1 2 3 4 t5 6 A7 8 45 0 1 9 10 z')
	assert path.instructions.len == 11
	assert path.instructions[0].type_ == .move
	assert path.instructions[1].type_ == .line
	assert path.instructions[1].absolute
	assert path.instructions[2].type_ == .line
	assert !path.instructions[2].absolute
	assert path.instructions[9].type_ == .elliptical_arc
	assert path.instructions[10].type_ == .close_path
	assert path.serialize() == 'M 1 2 L 3 4 l 5 -6 H 9 v 2 C 1 2 3 4 5 6 s 7 8 9 10 Q 1 2 3 4 t 5 6 A 7 8 45 0 1 9 10 Z'
}

fn test_path_requires_moveto_and_stops_at_invalid_data() {
	assert parse_path_data('L 1 2').instructions.len == 0
	partial := parse_path_data('M0 0 L10 10 A3 4 0 2 0 5 5')
	assert partial.instructions.len == 2
}

fn test_path_arc_flags_use_single_character_grammar() {
	compact := parse_path_data('M0 0 A3 4 0 0110 20')
	assert compact.instructions.len == 2
	assert compact.instructions[1].data == [3.0, 4.0, 0.0, 0.0, 1.0, 10.0, 20.0]
	assert parse_path_data('M0 0 A3 4 0 2 0 5 5').instructions.len == 1
}

fn test_path_absolute_and_relative_endpoints() {
	path := parse_path_data('M10 10 l5 2 h3 v-4 c0 0 1 1 2 2 z')
	assert path.endpoints() == [Point{ x: 10, y: 10 }, Point{ x: 15, y: 12 }, Point{ x: 18, y: 12 },
		Point{ x: 18, y: 8 }, Point{ x: 20, y: 10 }, Point{ x: 10, y: 10 }]
}

fn test_path_length_handles_lines_close_and_path_length_calibration() {
	path := parse_path_data('M50,100l0,0l0,-50l100,0l86.3325,122.665z')
	assert math.abs(path.length() - 500.0) < 0.0001

	mut element := new_element('path')
	element.attributes['d'] = 'M0,0L100,0L100,100'
	element.attributes['pathLength'] = '1000'
	assert math.abs(element.get_total_length() - 200.0) < 0.00001
}

fn test_path_length_handles_smooth_curves_and_elliptical_arcs() {
	// These pairs describe the same curves using explicit and reflected controls.
	cubic := parse_path_data('M0 0 C0 100 100 100 100 0 S200 -100 200 0')
	explicit_cubic := parse_path_data('M0 0 C0 100 100 100 100 0 C100 -100 200 -100 200 0')
	assert math.abs(cubic.length() - explicit_cubic.length()) < 0.000001
	quadratic := parse_path_data('M0 0 Q50 100 100 0 T200 0')
	explicit_quadratic := parse_path_data('M0 0 Q50 100 100 0 Q150 -100 200 0')
	assert math.abs(quadratic.length() - explicit_quadratic.length()) < 0.000001

	circle := parse_path_data('M10 0 A10 10 0 0 1 0 10 A10 10 0 0 1 -10 0 A10 10 0 0 1 0 -10 A10 10 0 0 1 10 0')
	assert math.abs(circle.length() - 20.0 * math.pi) < 0.000001
}

fn test_geometry_element_total_length_uses_viewport_for_percentages() {
	mut rect := new_element('rect')
	rect.attributes['width'] = '50'
	rect.attributes['height'] = '100%'
	rect.attributes['_viewport_width'] = '300'
	rect.attributes['_viewport_height'] = '50'
	assert rect.get_total_length() == 200
	assert rect.get_total_length_for_viewport(800, 25) == 150
}
