// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Stateful translation of SVG::AttributeParser. The parser owns one cursor and
// path command methods consume only the production they matched, just as the
// upstream GenericLexer implementation does.
module svg

pub struct AttributeParser {
mut:
	source       string
	offset       int
	instructions []PathInstruction
	// Reuse an embedded scanner: a mutable local scanner is boxed by current V
	// on every coordinate, retaining a separate allocation under -prealloc.
	scanner_ Scanner
}

pub fn AttributeParser.from_string(source string) AttributeParser {
	return AttributeParser{ source: source }
}

fn (parser &AttributeParser) remaining() string {
	return if parser.done() { '' } else { parser.source[parser.offset..] }
}

pub fn (parser &AttributeParser) done() bool {
	return parser.offset >= parser.source.len
}

pub fn (parser &AttributeParser) ch() u8 {
	return if parser.done() { u8(0) } else { parser.source[parser.offset] }
}

fn (parser &AttributeParser) ch_at(offset int) u8 {
	index := parser.offset + offset
	return if index >= parser.source.len { u8(0) } else { parser.source[index] }
}

pub fn (mut parser AttributeParser) consume() u8 {
	character := parser.ch()
	if !parser.done() {
		parser.offset++
	}
	return character
}

// match_ is the non-consuming predicate corresponding to AttributeParser::match.
pub fn (parser &AttributeParser) match_(character u8) bool {
	return !parser.done() && parser.ch() == character
}

fn (mut parser AttributeParser) consume_if(character u8) bool {
	if !parser.match_(character) {
		return false
	}
	parser.consume()
	return true
}

pub fn (parser &AttributeParser) match_whitespace() bool {
	return !parser.done() && is_space(parser.ch())
}

pub fn (parser &AttributeParser) match_comma_whitespace() bool {
	return parser.match_whitespace() || parser.match_(`,`)
}

pub fn (mut parser AttributeParser) parse_whitespace() bool {
	start := parser.offset
	for parser.match_whitespace() {
		parser.consume()
	}
	return parser.offset > start
}

pub fn (mut parser AttributeParser) parse_comma_whitespace() bool {
	start := parser.offset
	if parser.consume_if(`,`) {
		parser.parse_whitespace()
	} else {
		if !parser.parse_whitespace() {
			return false
		}
		parser.consume_if(`,`)
		parser.parse_whitespace()
	}
	return parser.offset > start
}

fn (parser &AttributeParser) match_length(allow_dot bool) bool {
	if parser.done() {
		return false
	}
	mut offset := 0
	if parser.ch_at(offset) in [`-`, `+`] {
		offset++
	}
	if allow_dot && parser.ch_at(offset) == `.` {
		offset++
	}
	return parser.ch_at(offset).is_digit()
}

pub fn (parser &AttributeParser) match_number() bool {
	return parser.match_length(true)
}

pub fn (parser &AttributeParser) match_coordinate() bool {
	return parser.match_length(true)
}

pub fn (parser &AttributeParser) match_integer() bool {
	return parser.match_length(false)
}

pub fn (mut parser AttributeParser) parse_sign() int {
	if parser.consume_if(`-`) {
		return -1
	}
	parser.consume_if(`+`)
	return 1
}

pub fn (mut parser AttributeParser) parse_nonnegative_number() ?f64 {
	parser.scanner_ = Scanner{ source: parser.source, index: parser.offset }
	value := parser.scanner_.nonnegative_number() or { return none }
	parser.offset = parser.scanner_.index
	return value
}

pub fn (mut parser AttributeParser) parse_number() ?f64 {
	sign := parser.parse_sign()
	value := parser.parse_nonnegative_number() or { return none }
	return f64(sign) * value
}

pub fn (mut parser AttributeParser) parse_flag() ?bool {
	if parser.consume_if(`0`) {
		return false
	}
	if parser.consume_if(`1`) {
		return true
	}
	return none
}

pub fn (mut parser AttributeParser) parse_integer() ?int {
	if !parser.match_integer() {
		return none
	}
	parser.scanner_ = Scanner{ source: parser.source, index: parser.offset }
	value := parser.scanner_.integer() or { return none }
	parser.offset = parser.scanner_.index
	return value
}

pub fn (mut parser AttributeParser) parse_length() ?f64 {
	return parser.parse_number()
}

pub fn (mut parser AttributeParser) parse_coordinate() ?f64 {
	return parser.parse_length()
}

pub fn (mut parser AttributeParser) parse_positive_length() ?f64 {
	value := parser.parse_length() or { return none }
	return if value < 0 { none } else { value }
}

pub fn (mut parser AttributeParser) parse_number_percentage() ?NumberPercentage {
	value := parser.parse_number() or { return none }
	return if parser.consume_if(`%`) { percentage(value) } else { number(value) }
}

pub fn (mut parser AttributeParser) parse_coordinate_pair() ?Point {
	x := parser.parse_coordinate() or { return none }
	if parser.match_comma_whitespace() {
		parser.parse_comma_whitespace()
	}
	y := parser.parse_coordinate() or { return none }
	return Point{ x: x, y: y }
}

fn (mut parser AttributeParser) parse_coordinate_pairs(count int) ?[]f64 {
	mut coordinates := []f64{cap: count * 2}
	for index in 0 .. count {
		point := parser.parse_coordinate_pair() or { return none }
		coordinates << point.x
		coordinates << point.y
		if index + 1 < count && parser.match_comma_whitespace() {
			parser.parse_comma_whitespace()
		}
	}
	return coordinates
}

pub fn (mut parser AttributeParser) parse_coordinate_pair_double() ?[]Point {
	coordinates := parser.parse_coordinate_pairs(2) or { return none }
	return [Point{ x: coordinates[0], y: coordinates[1] },
		Point{ x: coordinates[2], y: coordinates[3] }]
}

pub fn (mut parser AttributeParser) parse_coordinate_pair_triplet() ?[]Point {
	coordinates := parser.parse_coordinate_pairs(3) or { return none }
	return [Point{ x: coordinates[0], y: coordinates[1] },
		Point{ x: coordinates[2], y: coordinates[3] }, Point{ x: coordinates[4], y: coordinates[5] }]
}

pub fn (mut parser AttributeParser) parse_coordinate_sequence() []f64 {
	mut sequence := []f64{}
	for {
		coordinate := parser.parse_coordinate() or { break }
		sequence << coordinate
		if parser.match_comma_whitespace() {
			parser.parse_comma_whitespace()
		}
		if !parser.match_comma_whitespace() && !parser.match_coordinate() {
			break
		}
	}
	return sequence
}

pub fn (mut parser AttributeParser) parse_coordinate_pair_sequence() []Point {
	mut sequence := []Point{}
	for {
		point := parser.parse_coordinate_pair() or { break }
		sequence << point
		if parser.match_comma_whitespace() {
			parser.parse_comma_whitespace()
		}
		if !parser.match_comma_whitespace() && !parser.match_coordinate() {
			break
		}
	}
	return sequence
}

pub fn (mut parser AttributeParser) parse_elliptical_arc_argument() ?[]f64 {
	mut numbers := []f64{cap: 7}
	for _ in 0 .. 3 {
		numbers << parser.parse_number() or { return none }
		if parser.match_comma_whitespace() {
			parser.parse_comma_whitespace()
		}
	}
	numbers << if parser.parse_flag() or { return none } { 1.0 } else { 0.0 }
	if parser.match_comma_whitespace() {
		parser.parse_comma_whitespace()
	}
	numbers << if parser.parse_flag() or { return none } { 1.0 } else { 0.0 }
	if parser.match_comma_whitespace() {
		parser.parse_comma_whitespace()
	}
	point := parser.parse_coordinate_pair() or { return none }
	numbers << point.x
	numbers << point.y
	return numbers
}

fn (parser &AttributeParser) path() Path {
	return Path{ instructions: parser.instructions.clone() }
}

fn (mut parser AttributeParser) parse_moveto_internal() bool {
	absolute := parser.consume() == `M`
	parser.parse_whitespace()
	pairs := parser.parse_coordinate_pair_sequence()
	if pairs.len == 0 {
		return false
	}
	for index, pair in pairs {
		parser.instructions << PathInstruction{
			type_: if index == 0 { .move } else { .line }
			absolute: absolute
			data: [pair.x, pair.y]
		}
	}
	return true
}

fn (mut parser AttributeParser) parse_closepath_internal() bool {
	absolute := parser.consume() == `Z`
	parser.parse_whitespace()
	parser.instructions << PathInstruction{
		type_: .close_path
		absolute: absolute
	}
	return true
}

fn (mut parser AttributeParser) parse_pair_command(kind PathInstructionType) bool {
	absolute := parser.consume().is_capital()
	parser.parse_whitespace()
	pairs := parser.parse_coordinate_pair_sequence()
	if pairs.len == 0 {
		return false
	}
	for pair in pairs {
		parser.instructions << PathInstruction{
			type_: kind
			absolute: absolute
			data: [pair.x, pair.y]
		}
	}
	return true
}

fn (mut parser AttributeParser) parse_coordinate_command(kind PathInstructionType) bool {
	absolute := parser.consume().is_capital()
	parser.parse_whitespace()
	coordinates := parser.parse_coordinate_sequence()
	if coordinates.len == 0 {
		return false
	}
	for coordinate in coordinates {
		parser.instructions << PathInstruction{
			type_: kind
			absolute: absolute
			data: [coordinate]
		}
	}
	return true
}

fn (mut parser AttributeParser) parse_multi_pair_command(kind PathInstructionType, pair_count int) bool {
	absolute := parser.consume().is_capital()
	parser.parse_whitespace()
	mut parsed := false
	for {
		coordinates := parser.parse_coordinate_pairs(pair_count) or { break }
		parser.instructions << PathInstruction{
			type_: kind
			absolute: absolute
			data: coordinates
		}
		parsed = true
		if parser.match_comma_whitespace() {
			parser.parse_comma_whitespace()
		}
		if !parser.match_coordinate() {
			break
		}
	}
	return parsed
}

fn (mut parser AttributeParser) parse_elliptical_arc_internal() bool {
	absolute := parser.consume().is_capital()
	parser.parse_whitespace()
	mut parsed := false
	for {
		argument := parser.parse_elliptical_arc_argument() or { break }
		parser.instructions << PathInstruction{
			type_: .elliptical_arc
			absolute: absolute
			data: argument
		}
		parsed = true
		if parser.match_comma_whitespace() {
			parser.parse_comma_whitespace()
		}
		if !parser.match_coordinate() {
			break
		}
	}
	return parsed
}

fn (mut parser AttributeParser) parse_drawto_internal() bool {
	return match parser.ch() {
		`M`, `m` { parser.parse_moveto_internal() }
		`Z`, `z` { parser.parse_closepath_internal() }
		`L`, `l` { parser.parse_pair_command(.line) }
		`H`, `h` { parser.parse_coordinate_command(.horizontal_line) }
		`V`, `v` { parser.parse_coordinate_command(.vertical_line) }
		`C`, `c` { parser.parse_multi_pair_command(.curve, 3) }
		`S`, `s` { parser.parse_multi_pair_command(.smooth_curve, 2) }
		`Q`, `q` { parser.parse_multi_pair_command(.quadratic_bezier_curve, 2) }
		`T`, `t` { parser.parse_pair_command(.smooth_quadratic_bezier_curve) }
		`A`, `a` { parser.parse_elliptical_arc_internal() }
		else { false }
	}
}

pub fn (mut parser AttributeParser) parse_path_data() Path {
	parser.parse_whitespace()
	for !parser.done() {
		if !parser.parse_drawto_internal() {
			break
		}
	}
	if parser.instructions.len > 0 && parser.instructions[0].type_ != .move {
		return Path{}
	}
	return Path{ instructions: parser.instructions }
}

// These command entry points expose the same individual productions used by
// parse_path_data and retain the accumulated instruction list.
pub fn (mut parser AttributeParser) parse_drawto() Path {
	parser.parse_drawto_internal()
	return parser.path()
}

pub fn (mut parser AttributeParser) parse_moveto() Path {
	parser.parse_moveto_internal()
	return parser.path()
}

pub fn (mut parser AttributeParser) parse_closepath() Path {
	parser.parse_closepath_internal()
	return parser.path()
}

pub fn (mut parser AttributeParser) parse_lineto() Path {
	parser.parse_pair_command(.line)
	return parser.path()
}

pub fn (mut parser AttributeParser) parse_horizontal_lineto() Path {
	parser.parse_coordinate_command(.horizontal_line)
	return parser.path()
}

pub fn (mut parser AttributeParser) parse_vertical_lineto() Path {
	parser.parse_coordinate_command(.vertical_line)
	return parser.path()
}

pub fn (mut parser AttributeParser) parse_curveto() Path {
	parser.parse_multi_pair_command(.curve, 3)
	return parser.path()
}

pub fn (mut parser AttributeParser) parse_smooth_curveto() Path {
	parser.parse_multi_pair_command(.smooth_curve, 2)
	return parser.path()
}

pub fn (mut parser AttributeParser) parse_quadratic_bezier_curveto() Path {
	parser.parse_multi_pair_command(.quadratic_bezier_curve, 2)
	return parser.path()
}

pub fn (mut parser AttributeParser) parse_smooth_quadratic_bezier_curveto() Path {
	parser.parse_pair_command(.smooth_quadratic_bezier_curve)
	return parser.path()
}

pub fn (mut parser AttributeParser) parse_elliptical_arc() Path {
	parser.parse_elliptical_arc_internal()
	return parser.path()
}

pub fn (mut parser AttributeParser) parse_points() []Point {
	mut points := []Point{}
	parser.parse_whitespace()
	for !parser.done() {
		x := parser.parse_coordinate() or { return [] }
		parser.parse_comma_whitespace()
		if parser.done() {
			break
		}
		y := parser.parse_coordinate() or { return [] }
		points << Point{ x: x, y: y }
		parser.parse_comma_whitespace()
	}
	return points
}

pub fn (mut parser AttributeParser) parse_table_values() []f64 {
	values := svg.parse_table_values(parser.remaining())
	parser.offset = parser.source.len
	return values
}

pub fn (mut parser AttributeParser) parse_preserve_aspect_ratio() ?PreserveAspectRatio {
	value := svg.parse_preserve_aspect_ratio(parser.remaining()) or { return none }
	parser.offset = parser.source.len
	return value
}

pub fn (mut parser AttributeParser) parse_units() ?Units {
	value := svg.parse_units(parser.remaining()) or { return none }
	parser.offset = parser.source.len
	return value
}

pub fn (mut parser AttributeParser) parse_spread_method() ?SpreadMethod {
	value := svg.parse_spread_method(parser.remaining()) or { return none }
	parser.offset = parser.source.len
	return value
}

pub fn (mut parser AttributeParser) parse_viewbox() ?ViewBox {
	value := svg.parse_viewbox(parser.remaining()) or { return none }
	parser.offset = parser.source.len
	return value
}

pub fn (mut parser AttributeParser) parse_transform() ?[]Transform {
	value := svg.parse_transform(parser.remaining()) or { return none }
	parser.offset = parser.source.len
	return value
}
