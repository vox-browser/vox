// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Stateful entry points corresponding to SVG::AttributeParser. Public parse
// helpers below remain the canonical grammar implementation.
module svg

pub struct AttributeParser {
mut:
	source string
	offset int
}

pub fn AttributeParser.from_string(source string) AttributeParser {
	return AttributeParser{ source: source }
}

fn (parser &AttributeParser) remaining() string {
	return if parser.offset >= parser.source.len { '' } else { parser.source[parser.offset..] }
}

pub fn (parser &AttributeParser) ch() u8 {
	return if parser.offset < parser.source.len { parser.source[parser.offset] } else { u8(0) }
}

pub fn (mut parser AttributeParser) consume() u8 {
	character := parser.ch()
	if parser.offset < parser.source.len { parser.offset++ }
	return character
}

pub fn (mut parser AttributeParser) match_(character u8) bool {
	if parser.ch() != character { return false }
	parser.offset++
	return true
}

pub fn (mut parser AttributeParser) match_whitespace() bool {
	start := parser.offset
	for parser.offset < parser.source.len && is_space(parser.source[parser.offset]) { parser.offset++ }
	return parser.offset > start
}

pub fn (mut parser AttributeParser) match_comma_whitespace() bool {
	start := parser.offset
	parser.match_whitespace()
	if parser.offset < parser.source.len && parser.source[parser.offset] == `,` {
		parser.offset++
		parser.match_whitespace()
	}
	return parser.offset > start
}

pub fn (mut parser AttributeParser) parse_whitespace() bool { return parser.match_whitespace() }
pub fn (mut parser AttributeParser) parse_comma_whitespace() bool { return parser.match_comma_whitespace() }

fn (mut parser AttributeParser) consume_number() ?f64 {
	mut scanner := Scanner{ source: parser.source, index: parser.offset }
	value := scanner.number() or { return none }
	parser.offset = scanner.index
	return value
}

pub fn (mut parser AttributeParser) parse_number() ?f64 { return parser.consume_number() }

pub fn (mut parser AttributeParser) parse_nonnegative_number() ?f64 {
	value := parser.consume_number() or { return none }
	return if value < 0 { none } else { value }
}

pub fn (mut parser AttributeParser) parse_flag() ?bool {
	if parser.match_(`0`) { return false }
	if parser.match_(`1`) { return true }
	return none
}

pub fn (mut parser AttributeParser) parse_sign() int {
	if parser.match_(`-`) { return -1 }
	parser.match_(`+`)
	return 1
}

pub fn (mut parser AttributeParser) parse_integer() ?int {
	mut scanner := Scanner{ source: parser.source, index: parser.offset }
	value := scanner.integer() or { return none }
	parser.offset = scanner.index
	return value
}

pub fn (mut parser AttributeParser) parse_coordinate() ?f64 {
	value := svg.parse_coordinate(parser.remaining()) or { return none }
	parser.offset = parser.source.len
	return value
}

pub fn (mut parser AttributeParser) parse_length() ?f64 {
	value := svg.parse_length(parser.remaining()) or { return none }
	parser.offset = parser.source.len
	return value
}

pub fn (mut parser AttributeParser) parse_positive_length() ?f64 {
	value := svg.parse_positive_length(parser.remaining()) or { return none }
	parser.offset = parser.source.len
	return value
}

pub fn (mut parser AttributeParser) parse_number_percentage() ?NumberPercentage {
	value := svg.parse_number_percentage(parser.remaining()) or { return none }
	parser.offset = parser.source.len
	return value
}

pub fn (mut parser AttributeParser) parse_coordinate_pair() ?Point {
	values := parse_number_sequence(parser.remaining()) or { return none }
	if values.len < 2 { return none }
	parser.offset = parser.source.len
	return Point{ x: values[0], y: values[1] }
}

pub fn (mut parser AttributeParser) parse_coordinate_pair_double() ?[]Point {
	values := parse_number_sequence(parser.remaining()) or { return none }
	if values.len < 4 { return none }
	parser.offset = parser.source.len
	return [Point{ x: values[0], y: values[1] }, Point{ x: values[2], y: values[3] }]
}

pub fn (mut parser AttributeParser) parse_coordinate_pair_triplet() ?[]Point {
	values := parse_number_sequence(parser.remaining()) or { return none }
	if values.len < 6 { return none }
	parser.offset = parser.source.len
	return [Point{ x: values[0], y: values[1] }, Point{ x: values[2], y: values[3] },
		Point{ x: values[4], y: values[5] }]
}

pub fn (mut parser AttributeParser) parse_coordinate_sequence() []f64 {
	values := parse_number_sequence(parser.remaining()) or { return []f64{} }
	parser.offset = parser.source.len
	return values
}

pub fn (mut parser AttributeParser) parse_coordinate_pair_sequence() []Point {
	points := parse_points(parser.remaining())
	parser.offset = parser.source.len
	return points
}

pub fn (mut parser AttributeParser) parse_points() []Point {
	points := svg.parse_points(parser.remaining())
	parser.offset = parser.source.len
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

pub fn (mut parser AttributeParser) parse_path_data() Path {
	path := svg.parse_path_data(parser.remaining())
	parser.offset = parser.source.len
	return path
}

fn (mut parser AttributeParser) parse_path_command() Path {
	return parser.parse_path_data()
}

pub fn (mut parser AttributeParser) parse_drawto() Path { return parser.parse_path_command() }
pub fn (mut parser AttributeParser) parse_moveto() Path { return parser.parse_path_command() }
pub fn (mut parser AttributeParser) parse_closepath() Path { return parser.parse_path_command() }
pub fn (mut parser AttributeParser) parse_lineto() Path { return parser.parse_path_command() }
pub fn (mut parser AttributeParser) parse_horizontal_lineto() Path { return parser.parse_path_command() }
pub fn (mut parser AttributeParser) parse_vertical_lineto() Path { return parser.parse_path_command() }
pub fn (mut parser AttributeParser) parse_curveto() Path { return parser.parse_path_command() }
pub fn (mut parser AttributeParser) parse_smooth_curveto() Path { return parser.parse_path_command() }
pub fn (mut parser AttributeParser) parse_quadratic_bezier_curveto() Path { return parser.parse_path_command() }
pub fn (mut parser AttributeParser) parse_smooth_quadratic_bezier_curveto() Path { return parser.parse_path_command() }
pub fn (mut parser AttributeParser) parse_elliptical_arc() Path { return parser.parse_path_command() }
pub fn (mut parser AttributeParser) parse_elliptical_arc_argument() Path { return parser.parse_path_command() }

pub fn (mut parser AttributeParser) match_number() bool {
	start := parser.offset
	_ = parser.consume_number() or { return false }
	return parser.offset > start
}

pub fn (mut parser AttributeParser) match_coordinate() bool { return parser.match_number() }
pub fn (mut parser AttributeParser) match_length() bool { return parser.match_number() }
pub fn (mut parser AttributeParser) match_integer() bool {
	start := parser.offset
	_ = parser.parse_integer() or { return false }
	return parser.offset > start
}
