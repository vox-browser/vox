module svg

// Preserve the segment kinds while converting relative coordinates. Smooth
// curves remain smooth curves, and closing a subpath restores its start point.
pub fn (path Path) to_absolute() Path {
	mut result := []PathInstruction{cap:path.instructions.len}
	mut x, mut y := 0.0, 0.0
	mut start_x, mut start_y := 0.0, 0.0
	for instruction in path.instructions {
		mut data := instruction.data.clone()
		if !instruction.absolute {
			match instruction.type_ {
				.move, .line, .smooth_quadratic_bezier_curve { data[0] += x; data[1] += y }
				.horizontal_line { data[0] += x }
				.vertical_line { data[0] += y }
				.curve { for index in 0 .. 3 { data[index * 2] += x; data[index * 2 + 1] += y } }
				.smooth_curve, .quadratic_bezier_curve { for index in 0 .. 2 { data[index * 2] += x; data[index * 2 + 1] += y } }
				.elliptical_arc { data[5] += x; data[6] += y }
				.close_path {}
			}
		}
		match instruction.type_ {
			.move, .line, .smooth_quadratic_bezier_curve { x = data[0]; y = data[1] }
			.horizontal_line { x = data[0] }
			.vertical_line { y = data[0] }
			.curve { x = data[4]; y = data[5] }
			.smooth_curve, .quadratic_bezier_curve { x = data[2]; y = data[3] }
			.elliptical_arc { x = data[5]; y = data[6] }
			.close_path { x = start_x; y = start_y }
		}
		if instruction.type_ == .move { start_x = x; start_y = y }
		result << PathInstruction{type_:instruction.type_, absolute:true, data:data}
	}
	return Path{instructions:result}
}
