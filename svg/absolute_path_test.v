module svg

fn test_absolute_path_keeps_curve_controls_and_subpath_resets() {
	path := parse_path_data('m10 20 c1 2 3 4 5 6 s7 8 9 10 q1 2 3 4 t5 6 a7 8 9 0 1 10 11 z l2 3').to_absolute()
	assert path.instructions[1].data == [11.0, 22, 13, 24, 15, 26]
	assert path.instructions[2].data == [22.0, 34, 24, 36]
	assert path.instructions[3].data == [25.0, 38, 27, 40]
	assert path.instructions[4].data == [32.0, 46]
	assert path.instructions[5].data == [7.0, 8, 9, 0, 1, 42, 57]
	assert path.instructions[7].data == [12.0, 23]
	assert path.instructions.all(it.absolute)
}
