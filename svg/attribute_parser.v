module svg

import strconv

struct Scanner {
	source string
mut:
	index int
}

fn (scanner Scanner) done() bool {
	return scanner.index >= scanner.source.len
}

fn (scanner Scanner) current() u8 {
	return scanner.source[scanner.index]
}

fn is_space(character u8) bool {
	return character in [` `, `\t`, `\n`, `\r`, `\f`]
}

fn (mut scanner Scanner) whitespace() bool {
	start := scanner.index
	for !scanner.done() && is_space(scanner.current()) {
		scanner.index++
	}
	return scanner.index > start
}

fn (mut scanner Scanner) comma_whitespace() bool {
	had_space := scanner.whitespace()
	if !scanner.done() && scanner.current() == `,` {
		scanner.index++
		scanner.whitespace()
		return true
	}
	return had_space
}

fn (mut scanner Scanner) number() !f64 {
	start := scanner.index
	if !scanner.done() && scanner.current() in [`+`, `-`] {
		scanner.index++
	}
	mut digits := 0
	for !scanner.done() && scanner.current().is_digit() {
		scanner.index++
		digits++
	}
	if !scanner.done() && scanner.current() == `.` {
		scanner.index++
		for !scanner.done() && scanner.current().is_digit() {
			scanner.index++
			digits++
		}
	}
	if digits == 0 {
		scanner.index = start
		return error('Expected number')
	}
	if !scanner.done() && scanner.current() in [`e`, `E`] {
		exponent_start := scanner.index
		scanner.index++
		if !scanner.done() && scanner.current() in [`+`, `-`] {
			scanner.index++
		}
		mut exponent_digits := 0
		for !scanner.done() && scanner.current().is_digit() {
			scanner.index++
			exponent_digits++
		}
		if exponent_digits == 0 {
			scanner.index = exponent_start
		}
	}
	// The numeric parser consumes this span synchronously. Ordinary string
	// slicing copies every coordinate under current V, even for a cache hit.
	return strconv.atof64(unsafe { scanner.source.substr_unsafe(start, scanner.index) })!
}

fn (mut scanner Scanner) nonnegative_number() !f64 {
	if scanner.done() || scanner.current() in [`+`, `-`] {
		return error('Expected non-negative number')
	}
	return scanner.number()
}

fn (mut scanner Scanner) flag() !f64 {
	if scanner.done() || scanner.current() !in [`0`, `1`] {
		return error('Expected flag')
	}
	value := f64(scanner.current() - `0`)
	scanner.index++
	return value
}

fn (mut scanner Scanner) integer() !int {
	start := scanner.index
	if !scanner.done() && scanner.current() in [`+`, `-`] {
		scanner.index++
	}
	digit_start := scanner.index
	for !scanner.done() && scanner.current().is_digit() {
		scanner.index++
	}
	if digit_start == scanner.index {
		scanner.index = start
		return error('Expected integer')
	}
	return strconv.atoi(scanner.source[start..scanner.index])!
}

fn (mut scanner Scanner) identifier() string {
	start := scanner.index
	for !scanner.done() && (scanner.current().is_letter() || scanner.current() == `-`) {
		scanner.index++
	}
	return scanner.source[start..scanner.index]
}

pub fn parse_coordinate(input string) ?f64 {
	return parse_single_number(input)
}

pub fn parse_length(input string) ?f64 {
	return parse_single_number(input)
}

pub fn parse_positive_length(input string) ?f64 {
	value := parse_single_number(input) or { return none }
	if value < 0 {
		return none
	}
	return value
}

pub fn parse_integer(input string) ?int {
	mut scanner := Scanner{
		source: input
	}
	scanner.whitespace()
	value := scanner.integer() or { return none }
	scanner.whitespace()
	return if scanner.done() { value } else { none }
}

fn parse_single_number(input string) ?f64 {
	mut scanner := Scanner{
		source: input
	}
	scanner.whitespace()
	value := scanner.number() or { return none }
	scanner.whitespace()
	return if scanner.done() { value } else { none }
}

pub fn parse_number_percentage(input string) ?NumberPercentage {
	mut scanner := Scanner{
		source: input
	}
	scanner.whitespace()
	value := scanner.number() or { return none }
	mut is_percentage := false
	if !scanner.done() && scanner.current() == `%` {
		is_percentage = true
		scanner.index++
	}
	scanner.whitespace()
	if !scanner.done() {
		return none
	}
	return if is_percentage { percentage(value) } else { number(value) }
}

pub fn parse_number_sequence(input string) ![]f64 {
	mut scanner := Scanner{
		source: input
	}
	mut values := []f64{}
	scanner.whitespace()
	for !scanner.done() {
		values << scanner.number()!
		if scanner.done() {
			break
		}
		if !scanner.comma_whitespace() {
			return error('Expected comma or whitespace')
		}
	}
	return values
}

pub fn parse_table_values(input string) []f64 {
	mut scanner := Scanner{
		source: input
	}
	mut values := []f64{}
	for !scanner.done() {
		scanner.whitespace()
		value := scanner.nonnegative_number() or { return [] }
		values << value
		scanner.whitespace()
		if !scanner.done() && scanner.current() == `,` {
			scanner.index++
		}
	}
	return values
}

pub fn parse_points(input string) []Point {
	mut scanner := Scanner{
		source: input
	}
	mut points := []Point{}
	scanner.whitespace()
	for !scanner.done() {
		x := scanner.number() or {
			if points.len == 0 {
				return []
			}
			break
		}
		scanner.comma_whitespace()
		y := scanner.number() or { break }
		points << Point{
			x: x
			y: y
		}
		if scanner.done() {
			break
		}
		scanner.comma_whitespace()
	}
	return points
}

pub fn parse_preserve_aspect_ratio(input string) ?PreserveAspectRatio {
	parts := input.fields()
	if parts.len < 1 {
		return none
	}
	align := match parts[0] {
		'none' { Align.none_ }
		'xMinYMin' { Align.x_min_y_min }
		'xMidYMin' { Align.x_mid_y_min }
		'xMaxYMin' { Align.x_max_y_min }
		'xMinYMid' { Align.x_min_y_mid }
		'xMidYMid' { Align.x_mid_y_mid }
		'xMaxYMid' { Align.x_max_y_mid }
		'xMinYMax' { Align.x_min_y_max }
		'xMidYMax' { Align.x_mid_y_max }
		'xMaxYMax' { Align.x_max_y_max }
		else {
			return none
		}
	}
	meet_or_slice := if parts.len == 1 || parts[1] == 'meet' {
		MeetOrSlice.meet
	} else if parts[1] == 'slice' {
		MeetOrSlice.slice
	} else {
		return none
	}
	return PreserveAspectRatio{
		align: align
		meet_or_slice: meet_or_slice
	}
}

pub fn parse_units(input string) ?Units {
	value := input.trim_space().fields()
	if value.len == 0 {
		return none
	}
	return match value[0] {
		'userSpaceOnUse' { Units.user_space_on_use }
		'objectBoundingBox' { Units.object_bounding_box }
		else { none }
	}
}

pub fn parse_spread_method(input string) ?SpreadMethod {
	value := input.trim_space().fields()
	if value.len == 0 {
		return none
	}
	return match value[0] {
		'pad' { SpreadMethod.pad }
		'repeat' { SpreadMethod.repeat }
		'reflect' { SpreadMethod.reflect }
		else { none }
	}
}

pub fn parse_viewbox(input string) ?ViewBox {
	mut scanner := Scanner{source:input}
	mut values := [4]f64{}
	scanner.whitespace()
	for index in 0 .. 4 {
		values[index] = scanner.number() or { return none }
		if !scanner.done() && !scanner.comma_whitespace() { return none }
	}
	if !scanner.done() { return none }
	return ViewBox{
		min_x: values[0]
		min_y: values[1]
		width: values[2]
		height: values[3]
	}
}

pub fn parse_transform(input string) ?[]Transform {
	mut scanner := Scanner{
		source: input
	}
	mut transforms := []Transform{}
	scanner.whitespace()
	for !scanner.done() {
		name := scanner.identifier()
		if name.len == 0 {
			return none
		}
		scanner.whitespace()
		if scanner.done() || scanner.current() != `(` {
			return none
		}
		scanner.index++
		start := scanner.index
		mut depth_end := -1
		for !scanner.done() {
			if scanner.current() == `)` {
				depth_end = scanner.index
				break
			}
			scanner.index++
		}
		if depth_end < 0 {
			return none
		}
		parameters := parse_transform_parameters(scanner.source[start..depth_end]) or {
			return none
		}
		scanner.index++
		mut values := [6]f64{}
		kind := match name {
			'translate' {
				if parameters.len !in [1, 2] {
					return none
				}
				values[0] = parameters[0]
				values[1] = if parameters.len == 2 { parameters[1] } else { 0 }
				TransformKind.translate
			}
			'scale' {
				if parameters.len !in [1, 2] {
					return none
				}
				values[0] = parameters[0]
				values[1] = if parameters.len == 2 { parameters[1] } else { parameters[0] }
				TransformKind.scale
			}
			'rotate' {
				if parameters.len < 1 || parameters.len > 3 {
					return none
				}
				for index, parameter in parameters {
					values[index] = parameter
				}
				TransformKind.rotate
			}
			'skewX' {
				if parameters.len != 1 {
					return none
				}
				values[0] = parameters[0]
				TransformKind.skew_x
			}
			'skewY' {
				if parameters.len != 1 {
					return none
				}
				values[0] = parameters[0]
				TransformKind.skew_y
			}
			'matrix' {
				if parameters.len != 6 {
					return none
				}
				for index, parameter in parameters {
					values[index] = parameter
				}
				TransformKind.matrix
			}
			else {
				return none
			}
		}
		transforms << Transform{
			kind: kind
			values: values
		}
		scanner.whitespace()
		if !scanner.done() && scanner.current() == `,` {
			scanner.index++
			scanner.whitespace()
		}
	}
	return transforms
}

fn parse_transform_parameters(input string) ?[]f64 {
	mut scanner := Scanner{
		source: input
	}
	mut parameters := []f64{}
	scanner.whitespace()
	for !scanner.done() {
		parameters << scanner.number() or { return none }
		scanner.comma_whitespace()
	}
	return parameters
}
