module svg

import math
import strings
$if prealloc {
	import platform
}

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
	mut builder := strings.new_builder(16)
	instruction.append_serialization(mut builder)
	return builder.str()
}

fn (instruction PathInstruction) append_serialization(mut builder strings.Builder) {
	if instruction.type_ == .close_path {
		builder.write_u8(`Z`)
		return
	}
	mut letter := instruction_letter(instruction.type_)
	if !instruction.absolute {
		letter += 0x20
	}
	builder.write_u8(letter)
	for value in instruction.data {
		builder.write_u8(` `)
		builder.write_string(format_number(value))
	}
}

pub fn (path Path) serialize() string {
	if path.instructions.len == 0 {
		return ''
	}
	$if prealloc {
		mut scratch := platform.begin_thread_scratch('SVG path serialization')
		serialized := path.serialize_in_workspace()
		scratch.leave()
		owned := serialized.clone()
		scratch.finish()
		return owned
	}
	return path.serialize_in_workspace()
}

fn (path Path) serialize_in_workspace() string {
	mut builder := strings.new_builder(path.instructions.len * 16)
	for index, instruction in path.instructions {
		if index > 0 {
			builder.write_u8(` `)
		}
		instruction.append_serialization(mut builder)
	}
	return builder.str()
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
	mut parser := AttributeParser.from_string(input)
	return parser.parse_path_data()
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
				if !instruction.absolute {
					next = Point{
						x: next.x + current.x
						y: next.y + current.y
					}
				}
			}
			.smooth_curve, .quadratic_bezier_curve {
				next = Point{
					x: instruction.data[2]
					y: instruction.data[3]
				}
				if !instruction.absolute {
					next = Point{
						x: next.x + current.x
						y: next.y + current.y
					}
				}
			}
			.elliptical_arc {
				next = Point{
					x: instruction.data[5]
					y: instruction.data[6]
				}
				if !instruction.absolute {
					next = Point{
						x: next.x + current.x
						y: next.y + current.y
					}
				}
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

fn path_point_distance(a Point, b Point) f64 {
	return math.sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y))
}

fn path_point_midpoint(a Point, b Point) Point {
	return Point{
		x: (a.x + b.x) / 2.0
		y: (a.y + b.y) / 2.0
	}
}

fn quadratic_bezier_length(start Point, control Point, end Point, tolerance f64, depth int) f64 {
	chord := path_point_distance(start, end)
	control_polygon := path_point_distance(start, control) + path_point_distance(control, end)
	if depth >= 18 || control_polygon - chord <= tolerance {
		return (control_polygon + chord) / 2.0
	}
	start_control := path_point_midpoint(start, control)
	control_end := path_point_midpoint(control, end)
	middle := path_point_midpoint(start_control, control_end)
	return quadratic_bezier_length(start, start_control, middle, tolerance / 2.0, depth + 1) + quadratic_bezier_length(middle, control_end, end, tolerance / 2.0, depth + 1)
}

fn cubic_bezier_length(start Point, control_0 Point, control_1 Point, end Point, tolerance f64, depth int) f64 {
	chord := path_point_distance(start, end)
	control_polygon := path_point_distance(start, control_0) + path_point_distance(control_0, control_1) + path_point_distance(control_1, end)
	if depth >= 18 || control_polygon - chord <= tolerance {
		return (control_polygon + chord) / 2.0
	}
	start_control := path_point_midpoint(start, control_0)
	controls_middle := path_point_midpoint(control_0, control_1)
	control_end := path_point_midpoint(control_1, end)
	left_control := path_point_midpoint(start_control, controls_middle)
	right_control := path_point_midpoint(controls_middle, control_end)
	middle := path_point_midpoint(left_control, right_control)
	return cubic_bezier_length(start, start_control, left_control, middle, tolerance / 2.0, depth + 1) + cubic_bezier_length(middle, right_control, control_end, end, tolerance / 2.0, depth + 1)
}

fn arc_speed(radius_x f64, radius_y f64, angle f64) f64 {
	x := radius_x * math.sin(angle)
	y := radius_y * math.cos(angle)
	return math.sqrt(x * x + y * y)
}

fn adaptive_arc_length(radius_x f64, radius_y f64, start f64, end f64, start_speed f64, middle_speed f64, end_speed f64, estimate f64, tolerance f64, depth int) f64 {
	middle := (start + end) / 2.0
	left_middle := (start + middle) / 2.0
	right_middle := (middle + end) / 2.0
	left_middle_speed := arc_speed(radius_x, radius_y, left_middle)
	right_middle_speed := arc_speed(radius_x, radius_y, right_middle)
	left_estimate := (middle - start) * (start_speed + 4.0 * left_middle_speed + middle_speed) / 6.0
	right_estimate := (end - middle) * (middle_speed + 4.0 * right_middle_speed + end_speed) / 6.0
	refined := left_estimate + right_estimate
	if depth >= 18 || math.abs(refined - estimate) <= 15.0 * tolerance {
		return refined + (refined - estimate) / 15.0
	}
	return adaptive_arc_length(radius_x, radius_y, start, middle, start_speed, left_middle_speed, middle_speed, left_estimate, tolerance / 2.0, depth + 1) + adaptive_arc_length(radius_x, radius_y, middle, end, middle_speed, right_middle_speed, end_speed, right_estimate, tolerance / 2.0, depth + 1)
}

fn path_vector_angle(ux f64, uy f64, vx f64, vy f64) f64 {
	return math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
}

// SVG arcs use endpoint parameters. Resolve their corrected radii and angular
// span, then integrate the ellipse's speed. Rotation affects placement but not
// arc length.
fn elliptical_arc_length(start Point, end Point, raw_radius_x f64, raw_radius_y f64, rotation_degrees f64, large_arc bool, sweep bool) f64 {
	if start == end {
		return 0
	}
	mut radius_x := math.abs(raw_radius_x)
	mut radius_y := math.abs(raw_radius_y)
	if radius_x == 0 || radius_y == 0 {
		return path_point_distance(start, end)
	}
	rotation := rotation_degrees * math.pi / 180.0
	cosine := math.cos(rotation)
	sine := math.sin(rotation)
	half_dx := (start.x - end.x) / 2.0
	half_dy := (start.y - end.y) / 2.0
	x1_prime := cosine * half_dx + sine * half_dy
	y1_prime := -sine * half_dx + cosine * half_dy
	radii_scale := x1_prime * x1_prime / (radius_x * radius_x) + y1_prime * y1_prime / (radius_y * radius_y)
	if radii_scale > 1.0 {
		scale := math.sqrt(radii_scale)
		radius_x *= scale
		radius_y *= scale
	}
	rx2 := radius_x * radius_x
	ry2 := radius_y * radius_y
	xp2 := x1_prime * x1_prime
	yp2 := y1_prime * y1_prime
	denominator := rx2 * yp2 + ry2 * xp2
	if denominator == 0 {
		return path_point_distance(start, end)
	}
	coefficient_sign := if large_arc == sweep { -1.0 } else { 1.0 }
	coefficient := coefficient_sign * math.sqrt(math.max(0.0, (rx2 * ry2 - rx2 * yp2 - ry2 * xp2) / denominator))
	cx_prime := coefficient * radius_x * y1_prime / radius_y
	cy_prime := coefficient * -radius_y * x1_prime / radius_x
	start_unit_x := (x1_prime - cx_prime) / radius_x
	start_unit_y := (y1_prime - cy_prime) / radius_y
	end_unit_x := (-x1_prime - cx_prime) / radius_x
	end_unit_y := (-y1_prime - cy_prime) / radius_y
	start_angle := path_vector_angle(1.0, 0.0, start_unit_x, start_unit_y)
	mut angle_delta := path_vector_angle(start_unit_x, start_unit_y, end_unit_x, end_unit_y)
	if !sweep && angle_delta > 0 {
		angle_delta -= 2.0 * math.pi
	} else if sweep && angle_delta < 0 {
		angle_delta += 2.0 * math.pi
	}
	raw_end_angle := start_angle + angle_delta
	integration_start := math.min(start_angle, raw_end_angle)
	end_angle := math.max(start_angle, raw_end_angle)
	middle_angle := (integration_start + end_angle) / 2.0
	start_speed := arc_speed(radius_x, radius_y, integration_start)
	middle_speed := arc_speed(radius_x, radius_y, middle_angle)
	end_speed := arc_speed(radius_x, radius_y, end_angle)
	estimate := (end_angle - integration_start) * (start_speed + 4.0 * middle_speed + end_speed) / 6.0
	tolerance := 1.0e-9 * math.max(1.0, estimate)
	return adaptive_arc_length(radius_x, radius_y, integration_start, end_angle, start_speed, middle_speed, end_speed, estimate, tolerance, 0)
}

fn absolute_path_point(current Point, x f64, y f64, absolute bool) Point {
	return Point{
		x: x + if absolute { 0 } else { current.x }
		y: y + if absolute { 0 } else { current.y }
	}
}

// Length returns the geometric length of every contour in the path. In
// particular, SVG's pathLength attribute is intentionally not involved: it is
// only a calibration value for other distance computations.
pub fn (path Path) length() f64 {
	mut length := 0.0
	mut current := Point{}
	mut subpath := Point{}
	mut last_cubic_control := Point{}
	mut last_quadratic_control := Point{}
	mut previous := PathInstructionType.close_path
	for instruction in path.instructions {
		match instruction.type_ {
			.move {
				current = absolute_path_point(current, instruction.data[0], instruction.data[1], instruction.absolute)
				subpath = current
			}
			.line, .smooth_quadratic_bezier_curve {
				end := absolute_path_point(current, instruction.data[0], instruction.data[1], instruction.absolute)
				if instruction.type_ == .line {
					length += path_point_distance(current, end)
				} else {
					control := if previous in [.quadratic_bezier_curve,
						.smooth_quadratic_bezier_curve] {
						Point{ x: 2.0 * current.x - last_quadratic_control.x, y: 2.0 * current.y - last_quadratic_control.y }
					} else {
						current
					}
					length += quadratic_bezier_length(current, control, end, 1.0e-9 * math.max(1.0, path_point_distance(current, control) + path_point_distance(control, end)), 0)
					last_quadratic_control = control
				}
				current = end
			}
			.horizontal_line {
				end := Point{
					x: instruction.data[0] + if instruction.absolute { 0 } else { current.x }
					y: current.y
				}
				length += path_point_distance(current, end)
				current = end
			}
			.vertical_line {
				end := Point{
					x: current.x
					y: instruction.data[0] + if instruction.absolute { 0 } else { current.y }
				}
				length += path_point_distance(current, end)
				current = end
			}
			.curve {
				control_0 := absolute_path_point(current, instruction.data[0], instruction.data[1], instruction.absolute)
				control_1 := absolute_path_point(current, instruction.data[2], instruction.data[3], instruction.absolute)
				end := absolute_path_point(current, instruction.data[4], instruction.data[5], instruction.absolute)
				control_length := path_point_distance(current, control_0) + path_point_distance(control_0, control_1) + path_point_distance(control_1, end)
				length += cubic_bezier_length(current, control_0, control_1, end, 1.0e-9 * math.max(1.0, control_length), 0)
				current = end
				last_cubic_control = control_1
			}
			.smooth_curve {
				control_0 := if previous in [.curve, .smooth_curve] {
					Point{ x: 2.0 * current.x - last_cubic_control.x, y: 2.0 * current.y - last_cubic_control.y }
				} else {
					current
				}
				control_1 := absolute_path_point(current, instruction.data[0], instruction.data[1], instruction.absolute)
				end := absolute_path_point(current, instruction.data[2], instruction.data[3], instruction.absolute)
				control_length := path_point_distance(current, control_0) + path_point_distance(control_0, control_1) + path_point_distance(control_1, end)
				length += cubic_bezier_length(current, control_0, control_1, end, 1.0e-9 * math.max(1.0, control_length), 0)
				current = end
				last_cubic_control = control_1
			}
			.quadratic_bezier_curve {
				control := absolute_path_point(current, instruction.data[0], instruction.data[1], instruction.absolute)
				end := absolute_path_point(current, instruction.data[2], instruction.data[3], instruction.absolute)
				control_length := path_point_distance(current, control) + path_point_distance(control, end)
				length += quadratic_bezier_length(current, control, end, 1.0e-9 * math.max(1.0, control_length), 0)
				current = end
				last_quadratic_control = control
			}
			.elliptical_arc {
				end := absolute_path_point(current, instruction.data[5], instruction.data[6], instruction.absolute)
				length += elliptical_arc_length(current, end, instruction.data[0], instruction.data[1], instruction.data[2], instruction.data[3] != 0, instruction.data[4] != 0)
				current = end
			}
			.close_path {
				length += path_point_distance(current, subpath)
				current = subpath
			}
		}
		previous = instruction.type_
	}
	return length
}
