module svg

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn reference_path_instruction_spelling(instruction PathInstruction) string {
	if instruction.type_ == .close_path { return 'Z' }
	mut letter := instruction_letter(instruction.type_).ascii_str()
	if !instruction.absolute { letter = letter.to_lower() }
	if instruction.data.len == 0 { return letter }
	return letter + ' ' + instruction.data.map(format_number(it)).join(' ')
}

fn test_path_instruction_serialization_preserves_letters_spacing_and_numbers() {
	for kind in [PathInstructionType.move, .close_path, .line, .horizontal_line, .vertical_line,
		.curve, .smooth_curve, .quadratic_bezier_curve, .smooth_quadratic_bezier_curve,
		.elliptical_arc] {
		for absolute in [true, false] {
			for count in 0 .. 9 {
				values := [f64(0), -0.0, 1, -1, 0.125, -2.5, 1e-20, 1e12]
				instruction := PathInstruction{
					type_:    kind
					absolute: absolute
					data:     values[..count]
				}
				assert instruction.serialize() == reference_path_instruction_spelling(instruction)
			}
		}
	}
}

fn long_serialization_test_path() Path {
	mut instructions := []PathInstruction{}
	for index in 0 .. 4096 {
		instructions << PathInstruction{
			type_:    .curve
			absolute: index % 2 == 0
			data:     [f64(index), f64(index) / 8, -f64(index), -0.0, 0.125, 1e-20]
		}
	}
	instructions << PathInstruction{
		type_: .close_path
	}
	return Path{
		instructions: instructions
	}
}

fn test_path_serialization_streams_long_paths_without_changing_command_boundaries() {
	assert Path{}.serialize() == ''
	path := long_serialization_test_path()
	assert path.serialize() == path.instructions.map(reference_path_instruction_spelling(it)).join(' ')
	assert Path{
		instructions: [PathInstruction{ type_: .close_path, absolute: false }]
	}.serialize() == 'Z'
}

fn retained_serialized_path() string {
	return long_serialization_test_path().serialize()
}

fn test_serialized_path_outlives_its_geometry_and_builder() {
	serialized := retained_serialized_path()
	for _ in 0 .. 3 {
		$if gcboehm ? { C.GC_gcollect() }
		assert serialized.starts_with('C 0 0 0 0 0.125 ')
		assert serialized.ends_with(' Z')
		assert unsafe { serialized.str[serialized.len] } == 0
	}
}
