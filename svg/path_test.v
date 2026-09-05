module svg

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
