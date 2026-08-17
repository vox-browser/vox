module svg

pub enum PathInstructionType {
	move
	close_path
	line
	horizontal_line
	vertical_line
	curve
	smooth_curve
	quadratic_bezier_curve
	smooth_quadratic_bezier_curve
	elliptical_arc
}

pub struct PathInstruction {
pub:
	type_    PathInstructionType
	absolute bool
	data     []f64
}

pub struct Path {
pub:
	instructions []PathInstruction
}

fn instruction_letter(kind PathInstructionType) u8 {
	return match kind {
		.move { `M` }
		.close_path { `Z` }
		.line { `L` }
		.horizontal_line { `H` }
		.vertical_line { `V` }
		.curve { `C` }
		.smooth_curve { `S` }
		.quadratic_bezier_curve { `Q` }
		.smooth_quadratic_bezier_curve { `T` }
		.elliptical_arc { `A` }
	}
}

pub fn (instruction PathInstruction) serialize() string {
	if instruction.type_ == .close_path {
		return 'Z'
	}
	mut letter := instruction_letter(instruction.type_).ascii_str()
	if !instruction.absolute {
		letter = letter.to_lower()
	}
	if instruction.data.len == 0 {
		return letter
	}
	return letter + instruction.data.map(format_number(it)).join(' ')
}

pub fn (path Path) serialize() string {
	return path.instructions.map(it.serialize()).join(' ')
}

fn path_arity(kind PathInstructionType) int {
	return match kind {
		.move, .line, .smooth_quadratic_bezier_curve { 2 }
		.horizontal_line, .vertical_line { 1 }
		.curve { 6 }
		.smooth_curve, .quadratic_bezier_curve { 4 }
		.elliptical_arc { 7 }
		.close_path { 0 }
	}
}

pub fn parse_path_data(input string) Path {
	mut scanner := Scanner{
		source: input
	}
	mut instructions := []PathInstruction{}
	mut command := u8(0)
	scanner.whitespace()
	for !scanner.done() {
		if scanner.current().is_letter() {
			command = scanner.current()
			scanner.index++
		} else if command == 0 {
			break
		}
		absolute := command.is_capital()
		upper := command.ascii_str().to_upper()[0]
		kind := match upper {
			`M` { PathInstructionType.move }
			`Z` { PathInstructionType.close_path }
			`L` { PathInstructionType.line }
			`H` { PathInstructionType.horizontal_line }
			`V` { PathInstructionType.vertical_line }
			`C` { PathInstructionType.curve }
			`S` { PathInstructionType.smooth_curve }
			`Q` { PathInstructionType.quadratic_bezier_curve }
			`T` { PathInstructionType.smooth_quadratic_bezier_curve }
			`A` { PathInstructionType.elliptical_arc }
			else { break }
		}
		scanner.whitespace()
		if kind == .close_path {
			instructions << PathInstruction{
				type_:    kind
				absolute: absolute
			}
			command = 0
			continue
		}
		arity := path_arity(kind)
		mut first_for_move := true
		mut parsed := false
		for !scanner.done() && !scanner.current().is_letter() {
			mut data := []f64{cap: arity}
			for index in 0 .. arity {
				value := if kind == .elliptical_arc && index in [3, 4] {
					scanner.flag() or { break }
				} else {
					scanner.number() or { break }
				}
				data << value
				if index + 1 < arity {
					scanner.comma_whitespace()
				}
			}
			if data.len != arity {
				break
			}
			actual_kind := if kind == .move && !first_for_move {
				PathInstructionType.line
			} else {
				kind
			}
			instructions << PathInstruction{
				type_:    actual_kind
				absolute: absolute
				data:     data
			}
			parsed = true
			first_for_move = false
			if !scanner.comma_whitespace() && (scanner.done() || scanner.current().is_letter()) {
				break
			}
		}
		if !parsed {
			break
		}
	}
	if instructions.len > 0 && instructions[0].type_ != .move {
		return Path{}
	}
	return Path{
		instructions: instructions
	}
}

// Endpoints reproduces the absolute/relative current-point state used by
// Path::to_gfx_path. Curves contribute their final point and close-path returns
// to the active subpath start.
pub fn (path Path) endpoints() []Point {
	mut result := []Point{}
	mut current := Point{}
	mut subpath := Point{}
	for instruction in path.instructions {
		mut next := current
		match instruction.type_ {
			.move, .line, .smooth_quadratic_bezier_curve {
				next = Point{
					x: instruction.data[0]
					y: instruction.data[1]
				}
				if !instruction.absolute {
					next = Point{
						x: next.x + current.x
						y: next.y + current.y
					}
				}
			}
			.horizontal_line {
				next = Point{
					x: instruction.data[0] + if instruction.absolute { 0 } else { current.x }
					y: current.y
				}
			}
			.vertical_line {
				next = Point{
					x: current.x
					y: instruction.data[0] + if instruction.absolute { 0 } else { current.y }
				}
			}
			.curve {
				next = Point{
					x: instruction.data[4]
					y: instruction.data[5]
				}
				if !instruction.absolute { next = Point{
						x: next.x + current.x
						y: next.y + current.y
					} }
			}
			.smooth_curve, .quadratic_bezier_curve {
				next = Point{
					x: instruction.data[2]
					y: instruction.data[3]
				}
				if !instruction.absolute { next = Point{
						x: next.x + current.x
						y: next.y + current.y
					} }
			}
			.elliptical_arc {
				next = Point{
					x: instruction.data[5]
					y: instruction.data[6]
				}
				if !instruction.absolute { next = Point{
						x: next.x + current.x
						y: next.y + current.y
					} }
			}
			.close_path {
				next = subpath
			}
		}
		if instruction.type_ == .move {
			subpath = next
		}
		current = next
		result << current
	}
	return result
}
